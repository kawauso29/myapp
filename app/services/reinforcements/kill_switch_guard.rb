module Reinforcements
  # Phase 26 / 補強16: 全ジョブ・全会議・全成果物出力の起動直前に有効な halt_* を確認する。
  # 該当があれば即時中断。他のすべての判断（監査拒否権含む）に優先する。
  class KillSwitchGuard
    def self.halted?(scope_level: nil, service_id: nil)
      OperatorOverrideLedger.halted?(scope_level: scope_level, service_id: service_id)
    end

    def self.ensure_not_halted!(scope_level: nil, service_id: nil)
      return true unless halted?(scope_level: scope_level, service_id: service_id)

      raise Halted.new(scope_level: scope_level, service_id: service_id)
    end

    # ブロック実行前に halt 確認。halt 中は実行せず nil を返す。
    def self.guarded(scope_level: nil, service_id: nil)
      return nil if halted?(scope_level: scope_level, service_id: service_id)

      yield
    end
  end
end
