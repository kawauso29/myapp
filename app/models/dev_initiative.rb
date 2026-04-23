class DevInitiative < ApplicationRecord
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
