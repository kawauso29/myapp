class DevInitiative < ApplicationRecord
  # PR2 以降: read-only 化（参照ソースから格下げ）。
  #
  # 正本は `TicketLedger.ai_sns_plan` 側に移行済み。本モデルは以下のためだけに残す:
  #   - 旧パス（plan_review.yml の Copilot 自動追加など）から `DevInitiative.create!` された
  #     内容を `Ledgers::AiSnsPlanSync` 経由で TicketLedger にミラーするための入口（sync 維持）
  #   - `Admin::AiSnsPlanService.legacy_notes_for` が `notes` を補助的に参照するため
  #
  # アプリ本体の状態管理（ステータス遷移・stale 検知・done 反映）はすべて TicketLedger 側で
  # 完結させる。本モデルへの新規書込は最小限とし、PR3 でテーブル自体を drop する。
  enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true
  enum :status, { todo: 0, in_progress: 1, done: 2 }, prefix: true

  validates :item_key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :priority, :status, presence: true

  scope :ordered, -> { order(priority: :desc, item_key: :asc) }
  scope :next_todo, -> { status_todo.ordered }

  # PR1（並走）: AI SNS 計画項目の正本を TicketLedger へ移行する過程で、
  # DevInitiative への書き込みを TicketLedger にミラーリングする。
  # PR2 で読取側を TicketLedger に切替、PR3 で本モデルを drop する。
  # ミラー失敗で DevInitiative 本体の保存を巻き戻さないため例外は warn ログに留める。
  after_save :mirror_to_ticket_ledger

  private

  def mirror_to_ticket_ledger
    Ledgers::AiSnsPlanSync.call(self)
  rescue StandardError => e
    Rails.logger.warn("[AiSnsPlanSync] mirror failed for item_key=#{item_key}: #{e.class}: #{e.message}")
  end
end
