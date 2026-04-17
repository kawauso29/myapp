module Ledgers
  # Phase 30b / 補強2: 会議を開く前に「必要ロールの充足」を検証する。
  #
  # 既存の Runner は `participants: definition.participant_roles` を無条件に
  # コピーしていたため、`role_fill_rate` が常に 1.0 になり §26 の本来の意図
  # （欠席を記録して会議健全性スコアに反映）が失われていた。
  #
  # PreflightValidator は `present_roles:` を受け取り、`participant_roles` の
  # 部分集合かを判定し `role_fill_rate` を算出する。`required_minimum:` 未満の
  # ときは `PreflightFailure` を raise して会議を開かない（§26.2）。
  class PreflightValidator
    class PreflightFailure < StandardError
      attr_reader :missing_roles, :role_fill_rate

      def initialize(missing_roles:, role_fill_rate:)
        @missing_roles = missing_roles
        @role_fill_rate = role_fill_rate
        super(
          "required roles not met: missing=#{missing_roles.join(',')} fill_rate=#{role_fill_rate}"
        )
      end
    end

    Result = Struct.new(:participants, :missing_roles, :role_fill_rate, :ok?, keyword_init: true)

    DEFAULT_REQUIRED_MINIMUM = 0.5

    # @param definition [MeetingDefinition]
    # @param present_roles [Array<String>, nil] 省略時は定義のすべてのロールが参加した扱い
    # @param required_minimum [Float] 0..1 の範囲
    def self.call(definition:, present_roles: nil, required_minimum: DEFAULT_REQUIRED_MINIMUM)
      required_roles = Array(definition.participant_roles).map(&:to_s)
      present = normalize(present_roles, required_roles)
      missing = required_roles - present
      fill_rate = compute_fill_rate(required_roles, present)

      if required_roles.any? && fill_rate < required_minimum
        raise PreflightFailure.new(missing_roles: missing, role_fill_rate: fill_rate)
      end

      Result.new(
        participants: present,
        missing_roles: missing,
        role_fill_rate: fill_rate,
        ok?: missing.empty?
      )
    end

    def self.normalize(present_roles, required_roles)
      return required_roles.dup if present_roles.nil?

      Array(present_roles).map(&:to_s).uniq
    end
    private_class_method :normalize

    def self.compute_fill_rate(required_roles, present)
      return 1.0 if required_roles.empty?

      matched = (required_roles & present).size
      (matched.to_f / required_roles.size).round(4)
    end
    private_class_method :compute_fill_rate
  end
end
