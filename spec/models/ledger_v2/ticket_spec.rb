require "rails_helper"

RSpec.describe LedgerV2::Ticket, type: :model do
  # 最小限の有効な属性を返すヘルパー
  def valid_attrs(overrides = {})
    { canonical_key: "ai_sns:global:post_count:low:2026w18", title: "投稿数が低下" }.merge(overrides)
  end

  describe "create（基本保存）" do
    it "必須カラムが揃っていれば保存できる" do
      ticket = described_class.new(valid_attrs)
      expect(ticket.save).to be true
    end

    it "デフォルトの status は open になる" do
      ticket = described_class.create!(valid_attrs)
      expect(ticket.status_open?).to be true
    end

    it "デフォルトの severity は medium になる" do
      ticket = described_class.create!(valid_attrs)
      expect(ticket.severity_medium?).to be true
    end

    it "デフォルトの review_status は not_required になる" do
      ticket = described_class.create!(valid_attrs)
      expect(ticket.review_status_not_required?).to be true
    end

    it "デフォルトの human_decision は none になる" do
      ticket = described_class.create!(valid_attrs)
      expect(ticket.human_decision_none?).to be true
    end
  end

  describe "バリデーション" do
    it "canonical_key が空だと無効" do
      ticket = described_class.new(valid_attrs(canonical_key: nil))
      expect(ticket).not_to be_valid
      expect(ticket.errors[:canonical_key]).to be_present
    end

    it "title が空だと無効" do
      ticket = described_class.new(valid_attrs(title: nil))
      expect(ticket).not_to be_valid
      expect(ticket.errors[:title]).to be_present
    end
  end

  describe "enum（status）" do
    it "すべての status 値を保存できる" do
      described_class.statuses.each_key do |s|
        ticket = described_class.create!(valid_attrs(canonical_key: "key:#{s}", status: s))
        expect(ticket.status).to eq(s)
      end
    end

    it "prefix つき述語メソッドが存在する" do
      ticket = described_class.create!(valid_attrs)
      expect(ticket).to respond_to(:status_open?)
      expect(ticket).not_to respond_to(:open?)
    end
  end

  describe "enum（severity）" do
    it "すべての severity 値を保存できる" do
      described_class.severities.each_key do |s|
        ticket = described_class.create!(valid_attrs(canonical_key: "key:sev:#{s}", severity: s))
        expect(ticket.severity).to eq(s)
      end
    end
  end

  describe "部分 unique index（canonical_key のアクティブ状態制約）" do
    it "同じ canonical_key で open の Ticket を 2 件作ろうとすると DB エラー" do
      key = "ci:main:success_rate:low:2026w18"
      described_class.create!(valid_attrs(canonical_key: key, status: :open))
      expect {
        described_class.create!(valid_attrs(canonical_key: key, status: :open))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "in_progress 状態でも同じ canonical_key は重複できない" do
      key = "ci:main:success_rate:low:2026w19"
      described_class.create!(valid_attrs(canonical_key: key, status: :in_progress))
      expect {
        described_class.create!(valid_attrs(canonical_key: key, status: :in_progress))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "deferred 状態でも同じ canonical_key は重複できない" do
      key = "ci:main:success_rate:low:2026w20"
      described_class.create!(valid_attrs(canonical_key: key, status: :deferred))
      expect {
        described_class.create!(valid_attrs(canonical_key: key, status: :deferred))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "resolved 後は同じ canonical_key で再起票できる" do
      key = "ai_sns:global:engagement:low:2026w18"
      described_class.create!(valid_attrs(canonical_key: key, status: :resolved))
      expect {
        described_class.create!(valid_attrs(canonical_key: key, status: :open))
      }.not_to raise_error
    end

    it "rejected 後は同じ canonical_key で再起票できる" do
      key = "ai_sns:global:engagement:low:2026w19"
      described_class.create!(valid_attrs(canonical_key: key, status: :rejected))
      expect {
        described_class.create!(valid_attrs(canonical_key: key, status: :open))
      }.not_to raise_error
    end
  end

  describe ".active_exists?" do
    it "open の Ticket があれば true を返す" do
      key = "ai_sns:global:reply_rate:low:2026w18"
      described_class.create!(valid_attrs(canonical_key: key, status: :open))
      expect(described_class.active_exists?(key)).to be true
    end

    it "resolved のみなら false を返す" do
      key = "ai_sns:global:reply_rate:low:2026w19"
      described_class.create!(valid_attrs(canonical_key: key, status: :resolved))
      expect(described_class.active_exists?(key)).to be false
    end

    it "canonical_key が存在しなければ false を返す" do
      expect(described_class.active_exists?("non:existent:key")).to be false
    end
  end

  describe "アソシエーション" do
    it "opened_by_run を持てる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      ticket = described_class.create!(valid_attrs(opened_by_run: run))
      expect(ticket.opened_by_run).to eq(run)
    end

    it "duplicate_of を持てる（self-referential）" do
      original = described_class.create!(valid_attrs(canonical_key: "base:key:2026w18", status: :resolved))
      dup = described_class.create!(valid_attrs(canonical_key: "dup:key:2026w18", status: :duplicate, duplicate_of: original))
      expect(dup.duplicate_of).to eq(original)
    end
  end
end
