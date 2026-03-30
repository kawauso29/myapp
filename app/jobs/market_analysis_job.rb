# 定期実行ジョブ: 市場分析 + 売買判断
#
# Sidekiq で定期的に実行（例: 5分ごと）
# 市場データを収集し、全エージェントを実行して TradeDecision を記録する。
#
# 将来的にはデータソース（MT4 EA / 外部API）からリアルタイムデータを取得する。
# 現在はデモ用のスタブデータを使用する。
#
# APIコスト最適化:
#   1. 市場時間外（NAS100が取引されていない時間）はスキップ
#   2. Layer 0 で dangerous/low-confidence と判断された場合はエージェントを呼ばない
#      （Orchestrator が担保しているが、ジョブ層でも早期 return する）
#   3. エージェントは安価な Haiku を使用（base_agent.rb 参照）
#
# 概算コスト:
#   市場時間内のみ・Haiku 使用 → 約 $0.10〜0.20/日

class MarketAnalysisJob < ApplicationJob
  # NAS100（CME先物）の主要取引時間帯（米国東部時間）
  # 実質的にボラティリティと流動性がある時間帯に絞る
  # 日本時間: 22:30〜翌6:00（夏時間）/ 23:30〜翌7:00（冬時間）
  MARKET_OPEN_HOUR_ET  = 9   # 9:30 ET
  MARKET_CLOSE_HOUR_ET = 16  # 16:00 ET（通常セッション終了）

  queue_as :market_analysis

  def perform
    unless market_open?
      Rails.logger.info "[MarketAnalysisJob] 市場時間外のためスキップ (#{Time.current})"
      return
    end

    Rails.logger.info "[MarketAnalysisJob] 市場分析開始 #{Time.current}"

    market_data = fetch_market_data

    snapshot  = Market::StateClassifier.new.classify(market_data)
    Rails.logger.info "[MarketAnalysisJob] 市場状態: #{snapshot.state} (確信度: #{(snapshot.state_confidence.to_f * 100).round}%)"

    decision      = Orchestrator.new.evaluate(snapshot)
    final_decision = RiskManager.new.validate(decision)

    Rails.logger.info "[MarketAnalysisJob] 判断: #{final_decision.decision} | スコア: #{final_decision.final_score&.round(1)} | 方向: #{final_decision.direction || "なし"}"

    if final_decision.decision == "skip"
      Rails.logger.info "[MarketAnalysisJob] 見送り理由: #{final_decision.skip_reason}"
    end
  rescue => e
    Rails.logger.error "[MarketAnalysisJob] エラー: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  # 市場データの取得
  # TODO: 外部APIやMT4 EAからリアルタイムデータを取得する実装に置き換える
  def fetch_market_data
    {
      nas100_price:          fetch_nas100_price,
      nas100_volume:         nil,
      vix:                   fetch_vix,
      dxy:                   nil,
      spread_pips:           nil,
      normal_spread:         nil,
      hourly_range:          nil,
      avg_hourly_range:      nil,
      adx:                   nil,
      price_above_ema200:    nil,
      high_impact_event_soon: check_high_impact_event,
      mag7_earnings_today:   false,
      fomc_today:            false
    }
  end

  # NAS100の主要取引時間内かどうかを確認
  # 週末・祝日は除外（簡易実装）
  def market_open?
    now_et = Time.current.in_time_zone("Eastern Time (US & Canada)")
    return false if now_et.saturday? || now_et.sunday?

    hour = now_et.hour
    hour >= MARKET_OPEN_HOUR_ET && hour < MARKET_CLOSE_HOUR_ET
  end

  def fetch_nas100_price
    # TODO: 外部APIから取得
    nil
  end

  def fetch_vix
    # TODO: 外部APIから取得（Yahoo Finance等）
    nil
  end

  def check_high_impact_event
    # TODO: 経済指標カレンダーAPIから取得（Tradays等）
    false
  end
end
