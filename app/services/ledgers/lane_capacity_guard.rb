module Ledgers
  # Phase 36 / §13: 28日運営レーンの WIP 上限を守るためのガード。
  #
  # 起票直前に `allowed?` を呼び、false の場合は起票をブロックするか、
  # holding queue に回す設計にする。既定では wip_cap を超過したら false。
  class LaneCapacityGuard
    WIP_STATUSES = %w[waiting_review approved planned executing].freeze

    def self.allowed?(operating_lane:, scope_level: :service, service_id: "ai_sns")
      new(operating_lane: operating_lane, scope_level: scope_level, service_id: service_id).allowed?
    end

    def self.current_usage(operating_lane:, scope_level: :service, service_id: "ai_sns")
      new(operating_lane: operating_lane, scope_level: scope_level, service_id: service_id).current_usage
    end

    def initialize(operating_lane:, scope_level:, service_id:)
      @operating_lane = operating_lane.to_sym
      @scope_level = scope_level.to_sym
      @service_id = service_id
    end

    def allowed?
      cap = cap_value
      return true if cap.nil? # 設定なしなら無制限

      current_usage < cap
    end

    def current_usage
      TicketLedger
        .where(operating_lane: TicketLedger.operating_lanes[lane_enum_key])
        .where(service_id: @service_id)
        .where(status: WIP_STATUSES.map { |s| TicketLedger.statuses[s] })
        .count
    end

    private

    # `quarterly_review` は TicketLedger では `quarterly_review_lane` にマップされている
    def lane_enum_key
      return "quarterly_review_lane" if @operating_lane.to_s == "quarterly_review"

      @operating_lane.to_s
    end

    def cap_value
      cap = LaneCapacityCap.find_by(
        scope_level: LaneCapacityCap.scope_levels[@scope_level.to_s],
        service_id: @service_id,
        operating_lane: LaneCapacityCap.operating_lanes[@operating_lane.to_s]
      )
      cap ||= LaneCapacityCap.find_by(
        scope_level: nil,
        service_id: nil,
        operating_lane: LaneCapacityCap.operating_lanes[@operating_lane.to_s]
      )
      cap&.wip_cap
    end
  end
end
