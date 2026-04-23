class DevInitiative < ApplicationRecord
  # PR2 以降: read-only 化（参照ソースから格下げ）。PR4: notes も TicketLedger 側に正規化済み。
  #
  # 正本は `TicketLedger.ai_sns_plan` 側に移行済み。本モデルは以下のためだけに残す:
  #   - 旧パス（古いコード経路から `DevInitiative.create!` された場合）の内容を
  #     `Ledgers::AiSnsPlanSync` 経由で TicketLedger にミラーするための入口（sync 維持）
  #
  # アプリ本体の状態管理（ステータス遷移・stale 検知・done 反映・notes）はすべて TicketLedger
  # 側で完結する。本モデルへの新規書込は最小限とし、後続 PR でテーブル自体を drop する。
  enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true
  enum :status, { todo: 0, in_progress: 1, done: 2 }, prefix: true

  validates :item_key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :priority, :status, presence: true

  scope :ordered, -> { order(priority: :desc, item_key: :asc) }
  scope :next_todo, -> { status_todo.ordered }

  # PR1（並走）: AI SNS 計画項目の正本を TicketLedger へ移行する過程で、
  # DevInitiative への書き込みを TicketLedger にミラーリングする。
  # ミラー失敗で DevInitiative 本体の保存を巻き戻さないため例外は warn ログに留める。
  after_save :mirror_to_ticket_ledger

  private

  def mirror_to_ticket_ledger
    Ledgers::AiSnsPlanSync.call(self)
  rescue StandardError => e
    Rails.logger.warn("[AiSnsPlanSync] mirror failed for item_key=#{item_key}: #{e.class}: #{e.message}")
  end
end
