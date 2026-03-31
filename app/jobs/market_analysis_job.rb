# 定期実行ジョブ: 市場分析 + 売買判断
#
# Solid Queue で定期的に実行（15分ごと・市場時間内のみ）
# Market::DataFetcher でデータを取得し、全レイヤーを実行して TradeDecision を記録する。
#
# APIコスト最適化:
#   1. 市場時間外（NAS100が取引されていない時間）はスキップ
#   2. dangerous/low-confidence はエージェントを呼ばない（Orchestrator が担保）
#   3. エージェントはエージェント別モデル（nano/mini）を使用
#
# 概算コスト: nano×3 + mini×2・市場時間内のみ → 約 $0.80/月

class MarketAnalysisJob < ApplicationJob
  # NAS100（CME先物）の主要取引時間帯（米国東部時間）
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

    market_data = Market::DataFetcher.new.fetch

    snapshot = Market::StateClassifier.new.classify(market_data)
    Rails.logger.info "[MarketAnalysisJob] 市場状態: #{snapshot.state} (確信度: #{(snapshot.state_confidence.to_f * 100).round}%)"

    decision       = Orchestrator.new.evaluate(snapshot)
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

  # NAS100の主要取引時間内かどうかを確認（週末除外）
  def market_open?
    now_et = Time.current.in_time_zone("Eastern Time (US & Canada)")
    return false if now_et.saturday? || now_et.sunday?

    hour = now_et.hour
    hour >= MARKET_OPEN_HOUR_ET && hour < MARKET_CLOSE_HOUR_ET
  end
end
