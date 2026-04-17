module Stops
  # Phase 33 / 補強7 / §18: active な `StopLedger` がある scope の新規起票をブロックするガード。
  #
  # 使い方:
  #   Stops::EntryGuard.assert!(scope_level: :service, service_id: "ai_sns")
  #   # => `Stops::EntryGuard::Blocked` を raise（active stop がある場合）
  #
  #   result = Stops::EntryGuard.check(scope_level: :service, service_id: "ai_sns")
  #   result.allowed? # => false
  #   result.active_stops # => [StopLedger, ...]
  #
  # `scope_level: :company` はすべての ticket を、`:service`（service_id 付き）は
  # 該当サービスの起票のみをブロックする。`:portfolio` / `:cross_service` は
  # 上位 scope として常にブロック対象に含まれる。
  class EntryGuard
    class Blocked < StandardError
      attr_reader :active_stops

      def initialize(active_stops)
        @active_stops = active_stops
        summary = active_stops.map { |stop| self.class.format_stop(stop) }.join(", ")
        super("ticket creation is blocked by active stops: #{summary}")
      end

      # 単一 StopLedger を人間可読な 1 行表記に整形する（エラーメッセージ / ログ用）。
      def self.format_stop(stop)
        service_suffix = stop.service_id ? "(#{stop.service_id})" : ""
        "##{stop.id}:#{stop.trigger_type}/#{stop.scope_level}#{service_suffix}"
      end
    end

    Result = Struct.new(:allowed?, :active_stops, keyword_init: true) do
      def blocked?
        !allowed?
      end
    end

    def self.assert!(scope_level:, service_id: nil)
      result = check(scope_level: scope_level, service_id: service_id)
      raise Blocked.new(result.active_stops) if result.blocked?

      true
    end

    def self.check(scope_level:, service_id: nil)
      new(scope_level: scope_level, service_id: service_id).check
    end

    def initialize(scope_level:, service_id: nil)
      @scope_level = scope_level.to_s
      @service_id = service_id.presence
    end

    def check
      stops = relevant_active_stops
      Result.new(allowed?: stops.empty?, active_stops: stops)
    end

    private

    # 起票側の scope に対して「上位 scope で出た active stop」もブロック対象にする。
    # - company: すべての company active stop
    # - portfolio: company + portfolio active stop
    # - service: company + portfolio（service 共通） + 同一 service_id の service / cross_service stop
    def relevant_active_stops
      rel = StopLedger.status_active
      case @scope_level
      when "company"
        rel.where(scope_level: StopLedger.scope_levels["company"])
      when "portfolio"
        rel.where(scope_level: [ StopLedger.scope_levels["company"], StopLedger.scope_levels["portfolio"] ])
      else
        # service / cross_service 起票: 上位 scope も service_id 付き stop もすべて拾う
        service_scope = rel.where(scope_level: StopLedger.scope_levels["service"])
        service_scope = service_scope.where(service_id: @service_id) if @service_id
        cross_service_scope = rel.where(scope_level: StopLedger.scope_levels["cross_service"])

        upstream = rel.where(scope_level: [ StopLedger.scope_levels["company"], StopLedger.scope_levels["portfolio"] ])
        (upstream.to_a + service_scope.to_a + cross_service_scope.to_a).uniq
      end
    end
  end
end
