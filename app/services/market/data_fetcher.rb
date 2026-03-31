# 市場データ取得サービス
#
# Yahoo Finance の無料APIを使って以下を取得する（APIキー不要）:
#   - NAS100 価格・出来高・テクニカル指標
#   - VIX 指数
#
# 経済カレンダー（重要指標）は ForexFactory の RSS を使用する。

module Market
  class DataFetcher
    include HTTParty

    YAHOO_BASE = "https://query1.finance.yahoo.com/v8/finance/chart"

    # NAS100 先物（CME）のシンボル
    NAS100_SYMBOL = "NQ=F"
    VIX_SYMBOL    = "^VIX"
    DXY_SYMBOL    = "DX-Y.NYB"

    # @return [Hash] MarketStateClassifier に渡す market_data
    def fetch
      nas100 = fetch_quote(NAS100_SYMBOL)
      vix    = fetch_quote(VIX_SYMBOL)
      dxy    = fetch_quote(DXY_SYMBOL)

      technicals = calculate_technicals(NAS100_SYMBOL)
      event_flags = fetch_event_flags

      {
        nas100_price:           nas100[:price],
        nas100_volume:          nas100[:volume],
        vix:                    vix[:price],
        dxy:                    dxy[:price],
        spread_pips:            nil,     # MT4から取得（将来実装）
        normal_spread:          nil,
        hourly_range:           nas100[:hourly_range],
        avg_hourly_range:       technicals[:avg_hourly_range],
        adx:                    technicals[:adx],
        price_above_ema200:     technicals[:price_above_ema200],
        ema20:                  technicals[:ema20],
        ema50:                  technicals[:ema50],
        ema200:                 technicals[:ema200],
        rsi14:                  technicals[:rsi14],
        macd:                   technicals[:macd],
        macd_signal:            technicals[:macd_signal],
        bb_upper:               technicals[:bb_upper],
        bb_lower:               technicals[:bb_lower],
        support_level:          technicals[:support_level],
        resistance_level:       technicals[:resistance_level],
        momentum_1h:            technicals[:momentum_1h],
        momentum_4h:            technicals[:momentum_4h],
        momentum_1d:            technicals[:momentum_1d],
        volume_vs_avg:          technicals[:volume_vs_avg],
        high_impact_event_soon: event_flags[:high_impact_event_soon],
        mag7_earnings_today:    event_flags[:mag7_earnings_today],
        fomc_today:             event_flags[:fomc_today],
        today_events:           event_flags[:today_events],
        upcoming_releases:      event_flags[:upcoming_releases]
      }
    rescue => e
      Rails.logger.error "[DataFetcher] fetch error: #{e.message}"
      safe_fallback
    end

    private

    # Yahoo Finance から最新クォートを取得
    def fetch_quote(symbol)
      url      = "#{YAHOO_BASE}/#{URI.encode_www_form_component(symbol)}"
      response = HTTParty.get(url, query: { interval: "1m", range: "1d" },
                                   headers: { "User-Agent" => "Mozilla/5.0" },
                                   timeout: 10)

      result = response.dig("chart", "result", 0)
      return { price: nil, volume: nil, hourly_range: nil } unless result

      meta    = result["meta"] || {}
      quotes  = result.dig("indicators", "quote", 0) || {}
      closes  = quotes["close"]&.compact || []
      highs   = quotes["high"]&.compact || []
      lows    = quotes["low"]&.compact || []
      volumes = quotes["volume"]&.compact || []

      current_price = meta["regularMarketPrice"] || closes.last
      current_vol   = volumes.last

      # 直近1時間の値幅（直近60本の1分足）
      recent_highs = highs.last(60)
      recent_lows  = lows.last(60)
      hourly_range = if recent_highs.any? && recent_lows.any?
        recent_highs.max - recent_lows.min
      end

      { price: current_price, volume: current_vol, hourly_range: hourly_range }
    rescue => e
      Rails.logger.warn "[DataFetcher] #{symbol} quote error: #{e.message}"
      { price: nil, volume: nil, hourly_range: nil }
    end

    # テクニカル指標の計算（日足データから算出）
    def calculate_technicals(symbol)
      url      = "#{YAHOO_BASE}/#{URI.encode_www_form_component(symbol)}"
      response = HTTParty.get(url, query: { interval: "1d", range: "1y" },
                                   headers: { "User-Agent" => "Mozilla/5.0" },
                                   timeout: 10)

      result = response.dig("chart", "result", 0)
      return empty_technicals unless result

      quotes = result.dig("indicators", "quote", 0) || {}
      closes = quotes["close"]&.compact || []
      highs  = quotes["high"]&.compact || []
      lows   = quotes["low"]&.compact || []
      vols   = quotes["volume"]&.compact || []

      return empty_technicals if closes.size < 200

      current = closes.last

      # EMA 計算
      ema20  = ema(closes, 20)
      ema50  = ema(closes, 50)
      ema200 = ema(closes, 200)

      # RSI(14)
      rsi = rsi(closes, 14)

      # MACD(12,26,9)
      macd_line, signal_line = macd(closes)

      # ボリンジャーバンド(20)
      bb_upper, bb_lower = bollinger(closes, 20)

      # ADX(14) 簡易計算
      adx_val = adx(highs, lows, closes, 14)

      # 平均1時間値幅の代替として日足値幅の平均を使用（スケール調整済み）
      avg_daily_range = (0..29).map { |i| highs[-(i + 1)] - lows[-(i + 1)] }.sum / 30.0
      avg_hourly_range = avg_daily_range / 6.5  # 1日6.5時間として換算

      # モメンタム（n日前との変化率）
      momentum_1h = closes.size >= 2  ? ((current - closes[-2])  / closes[-2] * 100).round(3) : nil
      momentum_4h = closes.size >= 5  ? ((current - closes[-5])  / closes[-5] * 100).round(3) : nil
      momentum_1d = closes.size >= 21 ? ((current - closes[-21]) / closes[-21] * 100).round(3) : nil

      # 出来高（5日平均比）
      avg_vol_5d   = vols.last(5).sum.to_f / 5
      volume_vs_avg = avg_vol_5d > 0 ? (vols.last.to_f / avg_vol_5d).round(2) : nil

      # サポート・レジスタンス（直近20日の高値・安値）
      support_level    = lows.last(20).min
      resistance_level = highs.last(20).max

      {
        ema20:               ema20,
        ema50:               ema50,
        ema200:              ema200,
        price_above_ema200:  ema200 && current > ema200,
        rsi14:               rsi,
        macd:                macd_line,
        macd_signal:         signal_line,
        bb_upper:            bb_upper,
        bb_lower:            bb_lower,
        adx:                 adx_val,
        avg_hourly_range:    avg_hourly_range,
        momentum_1h:         momentum_1h,
        momentum_4h:         momentum_4h,
        momentum_1d:         momentum_1d,
        volume_vs_avg:       volume_vs_avg,
        support_level:       support_level,
        resistance_level:    resistance_level
      }
    rescue => e
      Rails.logger.warn "[DataFetcher] technicals error: #{e.message}"
      empty_technicals
    end

    # 重要経済指標・イベントのチェック
    # ForexFactory の RSS から当日・前後2時間のイベントを確認
    def fetch_event_flags
      now_et = Time.current.in_time_zone("Eastern Time (US & Canada)")
      rss    = fetch_forexfactory_rss

      high_impact_soon = rss.any? do |event|
        next false unless event[:impact] == "high"
        (event[:time] - Time.current).abs < 2.hours
      end

      fomc_today = rss.any? do |event|
        event[:impact] == "high" &&
        event[:title].to_s.match?(/FOMC|Federal.*Rate|Interest Rate/i) &&
        event[:time].to_date == Date.today
      end

      mag7_earnings = check_mag7_earnings(now_et)

      today_events = rss.select { |e| e[:time].to_date == Date.today }
                       .map { |e| "#{e[:time].strftime('%H:%M')} #{e[:title]} (#{e[:impact]})" }
                       .join(", ")

      upcoming = rss.select { |e| e[:time] > Time.current && e[:time] < 2.hours.from_now && e[:impact] == "high" }
                   .map { |e| "#{e[:time].strftime('%H:%M')} #{e[:title]}" }
                   .join(", ")

      {
        high_impact_event_soon: high_impact_soon,
        fomc_today:             fomc_today,
        mag7_earnings_today:    mag7_earnings,
        today_events:           today_events.presence || "なし",
        upcoming_releases:      upcoming.presence || "なし"
      }
    rescue => e
      Rails.logger.warn "[DataFetcher] event flags error: #{e.message}"
      { high_impact_event_soon: false, fomc_today: false, mag7_earnings_today: false,
        today_events: "取得失敗", upcoming_releases: "取得失敗" }
    end

    def fetch_forexfactory_rss
      response = HTTParty.get("https://nfs.faireconomy.media/ff_calendar_thisweek.json",
                              headers: { "User-Agent" => "Mozilla/5.0" },
                              timeout: 10)
      return [] unless response.code == 200

      JSON.parse(response.body).filter_map do |item|
        next unless item["country"] == "USD"

        time_str = "#{item['date']} #{item['time']}"
        time     = Time.zone.parse(time_str) rescue nil
        next unless time

        { title: item["title"], impact: item["impact"]&.downcase, time: time }
      end
    rescue => e
      Rails.logger.warn "[DataFetcher] ForexFactory RSS error: #{e.message}"
      []
    end

    MAG7 = {
      "AAPL"  => "Apple",
      "MSFT"  => "Microsoft",
      "GOOGL" => "Google",
      "AMZN"  => "Amazon",
      "META"  => "Meta",
      "NVDA"  => "Nvidia",
      "TSLA"  => "Tesla"
    }.freeze

    def check_mag7_earnings(now_et)
      MAG7.keys.any? do |ticker|
        url      = "#{YAHOO_BASE}/#{ticker}"
        response = HTTParty.get(url, query: { interval: "1d", range: "5d" },
                                     headers: { "User-Agent" => "Mozilla/5.0" },
                                     timeout: 5)
        earnings_ts = response.dig("chart", "result", 0, "meta", "earningsTimestamp")
        next false unless earnings_ts

        earnings_date = Time.at(earnings_ts).to_date
        earnings_date == now_et.to_date
      end
    rescue => e
      Rails.logger.warn "[DataFetcher] MAG7 earnings check error: #{e.message}"
      false
    end

    # ---- テクニカル指標の計算ヘルパー ----

    def ema(closes, period)
      return nil if closes.size < period

      k      = 2.0 / (period + 1)
      result = closes.first(period).sum / period.to_f
      closes[period..].each { |c| result = c * k + result * (1 - k) }
      result.round(2)
    end

    def rsi(closes, period = 14)
      return nil if closes.size < period + 1

      changes = closes.each_cons(2).map { |a, b| b - a }
      gains   = changes.last(period).map { |c| c > 0 ? c : 0 }
      losses  = changes.last(period).map { |c| c < 0 ? c.abs : 0 }

      avg_gain = gains.sum / period.to_f
      avg_loss = losses.sum / period.to_f
      return 50.0 if avg_loss.zero?

      rs = avg_gain / avg_loss
      (100 - 100 / (1 + rs)).round(2)
    end

    def macd(closes, fast: 12, slow: 26, signal: 9)
      return [ nil, nil ] if closes.size < slow + signal

      macd_line   = ema(closes, fast).to_f - ema(closes, slow).to_f
      macd_values = closes.last(signal).map.with_index do |_, i|
        subset = closes[..-(signal - i)]
        ema(subset, fast).to_f - ema(subset, slow).to_f
      end
      signal_line = macd_values.sum / signal.to_f

      [ macd_line.round(2), signal_line.round(2) ]
    end

    def bollinger(closes, period = 20)
      return [ nil, nil ] if closes.size < period

      slice  = closes.last(period)
      avg    = slice.sum / period.to_f
      stddev = Math.sqrt(slice.map { |c| (c - avg)**2 }.sum / period.to_f)

      [ (avg + 2 * stddev).round(2), (avg - 2 * stddev).round(2) ]
    end

    # ADX 簡易計算（Wilder's DMI）
    def adx(highs, lows, closes, period = 14)
      return nil if closes.size < period * 2

      tr_values  = []
      plus_dm    = []
      minus_dm   = []

      (1...closes.size).each do |i|
        high_diff = highs[i] - highs[i - 1]
        low_diff  = lows[i - 1] - lows[i]
        tr = [ highs[i] - lows[i], (highs[i] - closes[i - 1]).abs, (lows[i] - closes[i - 1]).abs ].max
        tr_values << tr
        plus_dm  << (high_diff > low_diff && high_diff > 0 ? high_diff : 0)
        minus_dm << (low_diff > high_diff && low_diff > 0 ? low_diff : 0)
      end

      atr       = tr_values.last(period).sum / period.to_f
      plus_dmi  = plus_dm.last(period).sum / period.to_f / atr * 100
      minus_dmi = minus_dm.last(period).sum / period.to_f / atr * 100
      dx        = ((plus_dmi - minus_dmi).abs / (plus_dmi + minus_dmi)) * 100 rescue 0

      dx.round(2)
    end

    def empty_technicals
      { ema20: nil, ema50: nil, ema200: nil, price_above_ema200: nil,
        rsi14: nil, macd: nil, macd_signal: nil, bb_upper: nil, bb_lower: nil,
        adx: nil, avg_hourly_range: nil, momentum_1h: nil, momentum_4h: nil,
        momentum_1d: nil, volume_vs_avg: nil, support_level: nil, resistance_level: nil }
    end

    def safe_fallback
      {
        nas100_price: nil, nas100_volume: nil, vix: nil, dxy: nil,
        spread_pips: nil, normal_spread: nil, hourly_range: nil, avg_hourly_range: nil,
        adx: nil, price_above_ema200: nil, high_impact_event_soon: false,
        mag7_earnings_today: false, fomc_today: false,
        today_events: "データ取得失敗", upcoming_releases: "データ取得失敗"
      }
    end
  end
end
