# 03. モデル + AASM 仕様

## ファイル配置

`app/models/linestamp/` 配下。

```ruby
# app/models/linestamp.rb (モジュール宣言)
module Linestamp
  def self.table_name_prefix = "linestamp_"
end
```

---

## Linestamp::Research

```ruby
# app/models/linestamp/research.rb
module Linestamp
  class Research < ApplicationRecord
    has_many :brands, class_name: "Linestamp::Brand", dependent: :restrict_with_error

    validates :slug,         presence: true, uniqueness: true,
                             format: { with: /\A\d{4}-W\d{2}\z/ }   # 2026-W21
    validates :brief,        presence: true
    validates :findings_md,  presence: true
  end
end
```

---

## Linestamp::Brand

```ruby
# app/models/linestamp/brand.rb
module Linestamp
  class Brand < ApplicationRecord
    include AASM

    belongs_to :research, class_name: "Linestamp::Research", optional: true
    has_many   :packs,    class_name: "Linestamp::Pack",     dependent: :restrict_with_error
    has_one_attached :base_image

    validates :slug,           presence: true, uniqueness: true,
                               format: { with: /\A[a-z][a-z0-9_]*\z/ }
    validates :series_name,    presence: true
    validates :character_name, presence: true
    validates :brand_theme_md, presence: true
    validates :base_md,        presence: true

    aasm column: :state, whiny_transitions: false do
      state :planned, initial: true
      state :prompt_ready
      state :base_ready
      state :error

      event :ready_prompt do
        transitions from: :planned, to: :prompt_ready,
                    guard: ->(brand) { brand.base_prompt.present? }
      end

      event :complete_base do
        transitions from: :prompt_ready, to: :base_ready,
                    guard: ->(brand) { brand.base_image.attached? }
      end

      event :fail, after: :record_error do
        transitions to: :error
      end
    end

    private

    def record_error(message = nil)
      update_column(:error_message, message) if message
    end
  end
end
```

---

## Linestamp::Pack

```ruby
# app/models/linestamp/pack.rb
module Linestamp
  class Pack < ApplicationRecord
    include AASM

    belongs_to :brand, class_name: "Linestamp::Brand"
    has_many   :stamps,       class_name: "Linestamp::Stamp",       dependent: :restrict_with_error
    has_many   :submissions,  class_name: "Linestamp::Submission",  dependent: :destroy
    has_one_attached :sheet_image

    validates :slug,         presence: true, uniqueness: { scope: :brand_id }
    validates :series_theme, presence: true
    validates :pack_md,      presence: true

    scope :approved,         -> { where(approved: true) }
    scope :pending_approval, -> { where(approved: false, state: %w[planned prompt_ready]) }

    aasm column: :state, whiny_transitions: false do
      state :planned, initial: true
      state :prompt_ready
      state :sheet_ready
      state :stamps_generating
      state :complete
      state :error

      event :ready_prompt do
        transitions from: :planned, to: :prompt_ready,
                    guard: ->(pack) { pack.sheet_prompt.present? }
      end

      event :complete_sheet do
        transitions from: :prompt_ready, to: :sheet_ready,
                    guard: ->(pack) { pack.approved? && pack.sheet_image.attached? }
      end

      event :start_stamps_generation do
        transitions from: :sheet_ready, to: :stamps_generating
      end

      event :complete_all, after: :ensure_draft_submission do
        transitions from: :stamps_generating, to: :complete,
                    guard: ->(pack) { pack.stamps.any? && pack.stamps.all?(&:processed?) }
      end

      event :fail, after: :record_error do
        transitions to: :error
      end
    end

    def approve!
      update!(approved: true, approved_at: Time.current)
    end

    def unapprove!
      update!(approved: false, approved_at: nil)
    end

    private

    def record_error(message = nil)
      update_column(:error_message, message) if message
    end

    def ensure_draft_submission
      submissions.create!(state: "drafting") unless submissions.exists?
    end
  end
end
```

---

## Linestamp::Stamp

```ruby
# app/models/linestamp/stamp.rb
module Linestamp
  class Stamp < ApplicationRecord
    include AASM

    belongs_to :pack, class_name: "Linestamp::Pack"
    has_one_attached :raw_image
    has_one_attached :processed_image

    validates :number, presence: true,
                       numericality: { only_integer: true, greater_than: 0 },
                       uniqueness: { scope: :pack_id }
    validates :label,  presence: true

    delegate :brand, to: :pack

    aasm column: :state, whiny_transitions: false do
      state :planned, initial: true
      state :prompt_ready
      state :raw_ready
      state :processed
      state :error

      event :ready_prompt do
        transitions from: :planned, to: :prompt_ready,
                    guard: ->(stamp) { stamp.prompt.present? }
      end

      event :complete_raw_upload do
        transitions from: :prompt_ready, to: :raw_ready,
                    guard: ->(stamp) { stamp.raw_image.attached? }
      end

      event :complete_processing do
        transitions from: :raw_ready, to: :processed,
                    guard: ->(stamp) { stamp.processed_image.attached? }
      end

      # processed_image を直接アップロードした場合の強制遷移
      event :force_processed do
        transitions from: [:planned, :prompt_ready, :raw_ready, :error], to: :processed,
                    guard: ->(stamp) { stamp.processed_image.attached? }
      end

      event :fail, after: :record_error do
        transitions to: :error
      end
    end

    def processed?
      state == "processed"
    end

    private

    def record_error(message = nil)
      update_column(:error_message, message) if message
    end
  end
end
```

---

## Linestamp::Submission

```ruby
# app/models/linestamp/submission.rb
module Linestamp
  class Submission < ApplicationRecord
    include AASM

    belongs_to :pack, class_name: "Linestamp::Pack"

    aasm column: :state, whiny_transitions: false do
      state :drafting, initial: true
      state :submitted
      state :approved
      state :rejected
      state :selling

      event :submit do
        transitions from: :drafting, to: :submitted, after: -> { update(submitted_at: Time.current) }
      end

      event :approve_by_line do
        transitions from: :submitted, to: :approved, after: -> { update(approved_at: Time.current) }
      end

      event :reject_by_line do
        transitions from: :submitted, to: :rejected
      end

      event :start_selling do
        transitions from: :approved, to: :selling
      end
    end
  end
end
```

---

## 状態遷移図(まとめ)

### Brand
```
planned → prompt_ready → base_ready
                ↓
   (管理画面で base_image アップロード時に遷移)
              error ← (任意の遷移失敗)
```

### Pack
```
planned → prompt_ready → sheet_ready → stamps_generating → complete
   (approval + sheet_image upload で遷移)
              error ← (任意の遷移失敗)
```

### Stamp
```
planned → prompt_ready → raw_ready → processed
                       ↘ processed (processed_image 直接 attach の場合、強制遷移)
              error ← (任意の遷移失敗)
```

SD ルートを採用しないため、`base_generating` / `sheet_generating` / `image_generating` / `processing` などの中間状態は削除。

### Submission
```
drafting → submitted → approved → selling
                    └→ rejected
```

---

## RSpec モデル仕様(目安)

`spec/models/linestamp/` 配下に以下を期待:
- `brand_spec.rb` — バリデーション + AASM 遷移
- `pack_spec.rb` — 同上 + approve! 動作
- `stamp_spec.rb` — 同上 + delegated brand
- `research_spec.rb` — slug format
- `submission_spec.rb` — 遷移

## 関連メソッド(便利系)

```ruby
# Pack#ready_for_image_generation?
# brand.base_ready? && pack.approved? && pack.prompt_ready? を1行で判定

# Pack#submittable?
# state=="complete" && submissions.empty? を判定

# Brand#total_processed_stamps
# packs.complete 配下の processed stamps 数
```
