module Reinforcements
  # §33.4 R2: ロール対立解決。
  # 同一 action / scope で role_A が approve し role_B が reject した場合に、
  # tiebreaker_role を参照して最終判定を返す。
  class ConflictResolver
    Result = Struct.new(:resolved, :winner_role, :tiebreaker_role, :reason, keyword_init: true)

    # decisions: [{ role:, action:, scope:, decision: :approve/:reject }]
    def self.resolve(action:, scope:, decisions:)
      new(action:, scope:, decisions:).resolve
    end

    def initialize(action:, scope:, decisions:)
      @action = action
      @scope = scope
      @decisions = decisions
    end

    def resolve
      approvals = decisions.select { |d| d[:decision].to_s == "approve" }
      rejections = decisions.select { |d| d[:decision].to_s == "reject" }

      return Result.new(resolved: true, winner_role: approvals.first&.dig(:role),
                        reason: "unanimous_approve") if rejections.empty?
      return Result.new(resolved: true, winner_role: rejections.first&.dig(:role),
                        reason: "unanimous_reject") if approvals.empty?

      # 対立発生 — tiebreaker_role を探す
      tiebreaker = find_tiebreaker
      return Result.new(resolved: false, reason: "no_tiebreaker_defined") unless tiebreaker

      tiebreaker_decision = decisions.find { |d| d[:role].to_s == tiebreaker.to_s }
      if tiebreaker_decision
        Result.new(
          resolved: true,
          winner_role: tiebreaker.to_s,
          tiebreaker_role: tiebreaker.to_s,
          reason: "tiebreaker_decided"
        )
      else
        Result.new(
          resolved: false,
          tiebreaker_role: tiebreaker.to_s,
          reason: "tiebreaker_not_voted"
        )
      end
    end

    private

    attr_reader :action, :scope, :decisions

    def find_tiebreaker
      # tiebreaker_role が設定されている permission 行を探す
      record = RolePermission.where(action: action, scope: scope)
                             .where.not(tiebreaker_role: nil)
                             .first
      record&.tiebreaker_role
    end
  end
end
