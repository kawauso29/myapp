module Reinforcements
  # Phase 24 / 補強14: 成果物出力前に compliance_rules を適用し、block/warn/audit を判定する。
  # block 相当の違反があれば `BlockingViolation` を発火し成果物の出力を中止させる。
  class ComplianceChecker
    Result = Struct.new(:violations, :blocked, keyword_init: true) do
      def blocked?
        blocked == true
      end

      def warnings
        violations.select(&:severity_warn?)
      end

      def audits
        violations.select(&:severity_audit?)
      end

      def blocks
        violations.select(&:severity_block?)
      end
    end

    def self.check(text, scope_level:, service_id: nil)
      violations = ComplianceRule.violations_for(text, scope_level: scope_level, service_id: service_id)
      Result.new(
        violations: violations,
        blocked: violations.any?(&:severity_block?)
      )
    end

    def self.check!(text, scope_level:, service_id: nil)
      result = check(text, scope_level: scope_level, service_id: service_id)
      return result unless result.blocked?

      raise BlockingViolation.new(result.blocks)
    end
  end
end
