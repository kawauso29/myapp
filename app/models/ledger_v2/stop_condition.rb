# LedgerV2::StopCondition — Runner や自動化を止める条件を表すモデル。
#
# 重要ルール:
# - active な StopCondition がある対象は RunExecutor が実行をブロックする
# - expires_at を過ぎた StopCondition は CircuitBreaker が有効でないとみなす（critical を除く）
# - 解除は人間のみ。AI が resolve! を呼んではいけない
# 設計の正本: ledger_v2_detailed_design.txt §「ledger_v2_stop_conditions」
module LedgerV2
  class StopCondition < ApplicationRecord
    self.table_name = "ledger_v2_stop_conditions"

    TARGET_TYPES = %w[runner feature ticket_creation artifact_generation auto_pr auto_merge auto_deploy all].freeze
    SEVERITIES   = %w[low medium high critical].freeze

    validates :target_type, presence: true, inclusion: { in: TARGET_TYPES }
    validates :severity,    presence: true, inclusion: { in: SEVERITIES }
    validates :reason,      presence: true
    validates :created_by,  presence: true

    # 有効中（active かつ expires_at が未来または nil）の条件を返す。
    scope :active_conditions, -> {
      where(active: true)
        .where("expires_at IS NULL OR expires_at > ?", Time.current)
    }

    # 指定 runner_name に対してアクティブなブロック条件を返す。
    # target_type: "all" はすべての Runner を止める。
    # target_type: "runner" かつ target_name が一致する場合も止める。
    scope :blocking_runner, ->(runner_name) {
      active_conditions.where(
        "(target_type = 'all') OR (target_type = 'runner' AND target_name = ?)",
        runner_name.to_s
      )
    }

    # 指定 feature_name（フラグ名: "auto_pr", "auto_merge", "auto_deploy" 等）に対してアクティブなブロック条件を返す。
    # target_type にフラグ名が完全一致するものだけを対象とする。
    # 注意: target_type: "all" は Runner 全体を止める意味で使用するが、feature フラグには影響させない。
    #       Runner は CircuitBreaker（blocking_runner? / blocking_runner スコープ）でブロックする。
    # 逆戻り条件（Phase G-5）: active StopCondition があれば Flags.enabled? が false を返すために使用する。
    scope :blocking_feature, ->(feature_name) {
      active_conditions.where(target_type: feature_name.to_s)
    }

    # @param runner_name [String] CamelCase の Runner 名（例: "DailyRunner"）
    # @return [Boolean]
    def self.blocking_runner?(runner_name)
      blocking_runner(runner_name).exists?
    end

    # @param feature_name [Symbol, String] フラグ名（例: :auto_merge, "auto_pr"）
    # @return [Boolean]
    def self.blocking_feature?(feature_name)
      blocking_feature(feature_name).exists?
    end

    # @param runner_name [String]
    # @return [String, nil] ブロック理由。ブロックされていなければ nil
    def self.blocking_reason_for_runner(runner_name)
      condition = blocking_runner(runner_name).order(Arel.sql("CASE severity WHEN 'critical' THEN 4 WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END DESC")).first
      condition&.reason
    end

    # StopCondition を解除する。解除は人間のみ。
    # @param resolved_by [String] 解除した人間の識別子
    def resolve!(resolved_by:)
      raise ArgumentError, "resolved_by は必須です" if resolved_by.blank?

      update!(
        active:      false,
        resolved_by: resolved_by,
        resolved_at: Time.current
      )
    end
  end
end
