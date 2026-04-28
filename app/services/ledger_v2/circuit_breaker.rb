# LedgerV2::CircuitBreaker — 実行前に「今そのRunnerを動かしてよいか」を判定する。
#
# 判定条件（本実装では StopCondition のみ。他条件は後続 Ticket で追加）:
# - active な StopCondition がある → 必ず止める
#
# 重要ルール:
# - RunExecutor の前に必ず通す（RunExecutor が呼ぶ）
# - blocked になったことも Run と Event に記録する（RunExecutor が担当）
# - StopCondition が active なら必ず止める
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::CircuitBreaker」
module LedgerV2
  module CircuitBreaker
    # @param runner_name [String] CamelCase の Runner 名（例: "DailyRunner"）
    # @return [Boolean]
    def self.blocked?(runner_name)
      StopCondition.blocking_runner?(runner_name)
    end

    # @param runner_name [String]
    # @return [String, nil] ブロック理由。ブロックされていなければ nil
    def self.reason_for(runner_name)
      return nil unless blocked?(runner_name)

      StopCondition.blocking_reason_for_runner(runner_name)
    end
  end
end
