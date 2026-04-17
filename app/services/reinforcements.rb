module Reinforcements
  # §33 補強10〜16 に対応する Phase 20〜26 のサービス層名前空間。
  # 台帳・モデル実装を既存ジョブ/成果物出力フローに接続する共通エントリポイントを提供する。
  class Error < StandardError; end

  # 補強12（権限マトリクス）違反
  class PermissionDenied < Error
    attr_reader :role, :action, :scope, :service_id

    def initialize(role:, action:, scope:, service_id: nil, message: nil)
      @role = role
      @action = action
      @scope = scope
      @service_id = service_id
      super(message || "role=#{role} is not permitted to #{action} at scope=#{scope} service_id=#{service_id.inspect}")
    end
  end

  # 補強14（コンプライアンス層）ブロッキング違反
  class BlockingViolation < Error
    attr_reader :violations

    def initialize(violations)
      @violations = Array(violations)
      names = @violations.map(&:name).join(", ")
      super("compliance blocking violations: #{names}")
    end
  end

  # 補強16（キルスイッチ）による停止状態
  class Halted < Error
    attr_reader :scope_level, :service_id

    def initialize(scope_level: nil, service_id: nil)
      @scope_level = scope_level
      @service_id = service_id
      super("operator kill-switch is active (scope_level=#{scope_level.inspect}, service_id=#{service_id.inspect})")
    end
  end
end
