# Layer 0: マーケット状態分類器
#
# 入力: 現在の市場データ（価格・VIX・出来高など）
# 出力: MarketSnapshot（状態 + 確信度）
#
# 状態:
#   trending_bull  - 上昇トレンド
#   trending_bear  - 下降トレンド
#   ranging        - レンジ相場
#   dangerous      - 危険相場（即時不執行）
#
# 「危険」判定は以下のいずれか1つで発動:
#   - VIX > 30
#   - 重要指標発表の前後2時間
#   - MAG7決算日 / FOMC当日
#   - スプレッド異常拡大
#   - 直近1時間の値幅が過去30日平均の3倍以上
#   - 分類器の確信度 < 70%

module Market
  class StateClassifier
    DANGEROUS_VIX_THRESHOLD       = 30.0
    DANGEROUS_VOLATILITY_MULTIPLE = 3.0
    CONFIDENCE_THRESHOLD          = 0.70
    TREND_ADX_THRESHOLD           = 25.0

    # 重要指標発表のブロック時間（前後 N 分）
    HIGH_IMPACT_BUFFER_MINUTES = 120

    # MAG7 銘柄（決算日チェック用）
    MAG7_TICKERS = %w[AAPL MSFT GOOGL AMZN META NVDA TSLA].freeze

    # @param market_data [Hash]
    #   :nas100_price     [Float]  現在の NAS100 価格
    #   :nas100_volume    [Float]  直近出来高
    #   :vix              [Float]  VIX 指数
    #   :dxy              [Float]  ドル指数
    #   :spread_pips      [Float]  現在のスプレッド（pips）
    #   :normal_spread    [Float]  通常スプレッド（pips）
    #   :hourly_range     [Float]  直近1時間の値幅
    #   :avg_hourly_range [Float]  過去30日の平均1時間値幅
    #   :adx              [Float]  ADX 値（トレンド強度）
    #   :price_above_ema200 [Boolean] 200EMA より上か
    #   :high_impact_event_soon [Boolean] 重要指標が前後2時間以内か
    #   :mag7_earnings_today [Boolean] MAG7 決算日か
    #   :fomc_today       [Boolean] FOMC 当日か
    # @return [MarketSnapshot]
    def classify(market_data)
      state, confidence = determine_state(market_data)

      # 確信度が閾値未満の場合は dangerous に格下げ
      if confidence < CONFIDENCE_THRESHOLD && state != "dangerous"
        state      = "dangerous"
        confidence = confidence
      end

      MarketSnapshot.create!(
        captured_at:      Time.current,
        state:            state,
        state_confidence: confidence,
        vix:              market_data[:vix],
        dxy:              market_data[:dxy],
        nas100_price:     market_data[:nas100_price],
        nas100_volume:    market_data[:nas100_volume],
        raw_data:         market_data
      )
    end

    private

    def determine_state(data)
      return [ "dangerous", 1.0 ] if dangerous?(data)

      classify_trend(data)
    end

    # いずれか1つでも該当すれば dangerous
    def dangerous?(data)
      return true if data[:vix].present? && data[:vix] > DANGEROUS_VIX_THRESHOLD
      return true if data[:high_impact_event_soon]
      return true if data[:mag7_earnings_today]
      return true if data[:fomc_today]
      return true if abnormal_spread?(data)
      return true if abnormal_volatility?(data)

      false
    end

    def abnormal_spread?(data)
      return false unless data[:spread_pips].present? && data[:normal_spread].present?

      data[:spread_pips] > data[:normal_spread] * 3
    end

    def abnormal_volatility?(data)
      return false unless data[:hourly_range].present? && data[:avg_hourly_range].present?

      data[:hourly_range] > data[:avg_hourly_range] * DANGEROUS_VOLATILITY_MULTIPLE
    end

    # ADX + EMA200 によるシンプルなトレンド分類
    # 戻り値: [state, confidence]
    def classify_trend(data)
      adx              = data[:adx].to_f
      above_ema200     = data[:price_above_ema200]

      if adx >= TREND_ADX_THRESHOLD
        if above_ema200
          confidence = normalize_adx_confidence(adx)
          [ "trending_bull", confidence ]
        else
          confidence = normalize_adx_confidence(adx)
          [ "trending_bear", confidence ]
        end
      else
        # レンジ相場: ADX が低いほど確信度が高い
        confidence = 1.0 - (adx / TREND_ADX_THRESHOLD)
        [ "ranging", confidence.clamp(0.0, 1.0) ]
      end
    end

    # ADX 値を確信度に変換（25→0.70, 50→1.0 を線形補間）
    def normalize_adx_confidence(adx)
      min_adx = TREND_ADX_THRESHOLD
      max_adx = 50.0
      result  = (adx - min_adx) / (max_adx - min_adx) * (1.0 - CONFIDENCE_THRESHOLD) + CONFIDENCE_THRESHOLD
      result.clamp(CONFIDENCE_THRESHOLD, 1.0)
    end
  end
end
