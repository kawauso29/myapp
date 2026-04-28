# LedgerV2::Review — 人間レビューの履歴を記録するイミュータブルなログ。
#
# 重要ルール:
# - Review は履歴として残す（更新前提ではなく追記前提）
# - Artifact / Ticket / StopCondition の現在状態は別途更新する
# - 誰が何を判断したか追えるようにする
#
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_reviews」
module LedgerV2
  class Review < ApplicationRecord
    self.table_name = "ledger_v2_reviews"

    # decision は string で保存（polymorphic な reviewable に対し意思決定種別を明示）。
    DECISIONS = %w[accepted rejected deferred needs_more_info edited cancelled].freeze

    belongs_to :reviewable, polymorphic: true
    belongs_to :reviewer,   polymorphic: true, optional: true

    validates :reviewable_type, presence: true
    validates :reviewable_id,   presence: true
    validates :decision,        presence: true, inclusion: { in: DECISIONS }
    validates :reviewed_at,     presence: true

    before_validation :set_reviewed_at_default

    private

    def set_reviewed_at_default
      self.reviewed_at ||= Time.current
    end
  end
end
