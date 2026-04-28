# LedgerV2::Ticket — 改善対象・異常・課題を表す台帳モデル。
#
# 重要ルール:
# - canonical_key は必須。canonical_key なしの自動起票は禁止（運用ルール §6）
# - open / in_progress / deferred 状態の canonical_key はデータベース制約で一意
# - resolved / rejected 後の再起票は canonical_key の再利用を許可する
# - 自動起票は必ず RunExecutor 経由（opened_by_run_id を持つ）
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_tickets」
module LedgerV2
  class Ticket < ApplicationRecord
    self.table_name = "ledger_v2_tickets"

    # status の整数値は partial unique index の WHERE 句（IN (0, 1, 2)）と一致させること。
    # 変更する場合は migration も同時に更新する。
    enum :status, {
      open:        0,
      in_progress: 1,
      deferred:    2,
      resolved:    3,
      rejected:    4,
      duplicate:   5,
      archived:    6
    }, prefix: true

    enum :severity, {
      low:      0,
      medium:   1,
      high:     2,
      critical: 3
    }, prefix: true

    enum :review_status, {
      not_required:   0,
      pending:        1,
      accepted:       2,
      review_rejected: 3,
      review_deferred: 4,
      needs_more_info: 5
    }, prefix: true

    enum :human_decision, {
      none:     0,
      accepted: 1,
      rejected: 2,
      deferred: 3,
      edited:   4
    }, prefix: true

    belongs_to :opened_by_run, class_name: "LedgerV2::Run", optional: true
    belongs_to :closed_by_run, class_name: "LedgerV2::Run", optional: true
    belongs_to :duplicate_of,  class_name: "LedgerV2::Ticket", optional: true,
                               foreign_key: :duplicate_of_id
    belongs_to :previous_ticket, class_name: "LedgerV2::Ticket", optional: true,
                                 foreign_key: :previous_ticket_id

    validates :canonical_key, presence: true
    validates :title,         presence: true
    validates :status,        presence: true
    validates :severity,      presence: true
    validates :review_status, presence: true
    validates :human_decision, presence: true

    # open / in_progress / deferred 状態のチケットを返す。
    scope :active, -> { where(status: [statuses[:open], statuses[:in_progress], statuses[:deferred]]) }

    # 指定 canonical_key でアクティブなチケットが存在するか。
    # TicketDeduplicator（Ticket 7）がこれを使って重複を抑止する。
    def self.active_exists?(canonical_key)
      active.where(canonical_key: canonical_key).exists?
    end
  end
end
