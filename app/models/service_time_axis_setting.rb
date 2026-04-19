# Phase 44a / §11.3.3: サービス固有の圧縮時間軸設定。
#
# `Ledgers::TimeAxis::INTERVALS` のデフォルト値を DB でオーバーライドできる。
# service_id + cadence の組み合わせが一意。未登録の場合はデフォルト定数にフォールバック。
class ServiceTimeAxisSetting < ApplicationRecord
  CADENCES = {
    daily: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    annual: 4,
    long_term: 5
  }.freeze

  enum :cadence, CADENCES, prefix: true

  validates :service_id, :cadence, :interval_seconds, presence: true
  validates :cadence, uniqueness: { scope: :service_id }
  validates :interval_seconds, numericality: { only_integer: true, greater_than: 0 }

  # @param service_id [String]
  # @param cadence [Symbol, String]
  # @return [ActiveSupport::Duration, nil] nil = DB に設定なし（デフォルト定数を使え）
  def self.interval_for(service_id:, cadence:)
    record = find_by(service_id: service_id, cadence: cadence)
    return nil unless record

    record.interval_seconds.seconds
  end
end
