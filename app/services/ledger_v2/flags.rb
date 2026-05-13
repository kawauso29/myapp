# LedgerV2::Flags — Ledger V2 機能の有効・無効を管理する。
#
# 設定は config/initializers/ledger_v2.rb の Rails.application.config.x.ledger_v2_flags で行う。
# 変更は人間のみ（Rails config 編集 or 環境変数）。AI による変更は禁止。
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::Flags」
module LedgerV2
  module Flags
    # v2 が管理するすべてのフラグ名。
    # 追加するときはここに追記し、config/initializers/ledger_v2.rb にもデフォルト値を追加する。
    ALL_FLAGS = %i[
      daily_runner
      weekly_runner
      health_snapshot
      ticket_creation
      artifact_generation
      monthly_runner
      quarterly_runner
      annual_runner
      auto_pr
      sync_draft_pr_status
      auto_merge
      evaluate_improvement
    ].freeze

    # フラグが有効かどうかを返す。
    # 未知のフラグ・未設定フラグは false を返す（保守的デフォルト）。
    #
    # 逆戻り条件（Phase G-5）:
    #   initializer で true に設定されていても、active な StopCondition が
    #   そのフラグ名または "all" を target_type に持つ場合は false を返す。
    #   これにより、human が StopCondition を作成するだけで機能を自動停止できる。
    #
    # @param flag_name [Symbol, String]
    # @return [Boolean]
    def self.enabled?(flag_name)
      flags = Rails.application.config.x.ledger_v2_flags
      return false unless flags[flag_name.to_sym]
      return false if StopCondition.blocking_feature?(flag_name)

      true
    end

    # 全フラグの現在値を Hash で返す。
    #
    # @return [Hash<Symbol, Boolean>]
    def self.all
      Rails.application.config.x.ledger_v2_flags
    end
  end
end
