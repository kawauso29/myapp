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
      auto_merge
    ].freeze

    # フラグが有効かどうかを返す。
    # 未知のフラグ・未設定フラグは false を返す（保守的デフォルト）。
    #
    # @param flag_name [Symbol, String]
    # @return [Boolean]
    def self.enabled?(flag_name)
      flags = Rails.application.config.x.ledger_v2_flags
      !!flags[flag_name.to_sym]
    end

    # 全フラグの現在値を Hash で返す。
    #
    # @return [Hash<Symbol, Boolean>]
    def self.all
      Rails.application.config.x.ledger_v2_flags
    end
  end
end
