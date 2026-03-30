# MT4 EA からのシグナルリクエストを処理するエンドポイント
#
# GET  /api/v1/signal   - 最新シグナルを返す（MT4 EAが定期的にポーリング）
# POST /api/v1/signal   - 新規分析を実行してシグナルを返す

module Api
  module V1
    class SignalsController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/signal
      # MT4 EA がポーリングする主要エンドポイント
      def show
        signal = Mt4Bridge.new.current_signal
        render json: signal
      end

      # POST /api/v1/signal
      # 市場データを受け取り、リアルタイム分析して即時シグナルを返す
      def create
        market_data = signal_params

        snapshot      = Market::StateClassifier.new.classify(market_data)
        decision      = Orchestrator.new.evaluate(snapshot)
        final_decision = RiskManager.new.validate(decision)

        signal = Mt4Bridge.new.current_signal
        render json: signal, status: :ok
      rescue => e
        Rails.logger.error "[SignalsController#create] #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        render json: { action: "hold", comment: "エラー: 安全のためhold", error: e.message }, status: :unprocessable_entity
      end

      private

      def signal_params
        params.permit(
          :nas100_price, :nas100_volume, :vix, :dxy, :spread_pips, :normal_spread,
          :hourly_range, :avg_hourly_range, :adx, :price_above_ema200,
          :high_impact_event_soon, :mag7_earnings_today, :fomc_today,
          :ema20, :ema50, :ema200, :rsi14, :macd, :macd_signal,
          :bb_upper, :bb_lower, :support_level, :resistance_level,
          :momentum_1h, :momentum_4h, :momentum_1d, :volume_vs_avg,
          :put_call_ratio, :institutional_flow, :us10y_yield, :risk_sentiment,
          :today_events, :upcoming_releases, :geopolitical_risk, :tomorrow_events,
          :fear_greed_index, :news_headlines, :news_sentiment_score,
          :social_sentiment, :analyst_consensus
        ).to_h.symbolize_keys
      end
    end
  end
end
