# LedgerV2::Artifact — Runner が生成した成果物（週次レビュー・改善案・分析結果等）。
#
# 重要ルール:
# - Runner が作る Artifact は原則 draft または pending（運用ルール §6）
# - 人間承認なしに published にしない
# - Artifact は Run および/または Ticket に紐づく
# - Artifact の採用率を HealthSnapshot で測る
#
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_artifacts」
module LedgerV2
  class Artifact < ApplicationRecord
    self.table_name = "ledger_v2_artifacts"

    # review_status: Runner 出力時は draft または pending、人間承認後に published に遷移する。
    enum :review_status, {
      draft:           0,
      pending:         1,
      accepted:        2,
      review_rejected: 3,
      review_deferred: 4,
      needs_more_info: 5,
      published:       6
    }, prefix: true

    belongs_to :run,             class_name: "LedgerV2::Run",    optional: true
    belongs_to :related_ticket,  class_name: "LedgerV2::Ticket", optional: true

    validates :artifact_type, presence: true
    validates :title,         presence: true
    validates :format,        presence: true
    validates :review_status, presence: true

    # publish 待ちの Artifact（draft / pending）を返す。
    scope :awaiting_review, -> {
      where(review_status: [review_statuses[:draft], review_statuses[:pending]])
    }

    # 公開済みの Artifact を返す。
    scope :published_only, -> { where(review_status: review_statuses[:published]) }
  end
end
