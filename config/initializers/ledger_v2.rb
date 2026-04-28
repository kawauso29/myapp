# LedgerV2 のデフォルト設定。
#
# フラグ変更は人間のみ行う。AI による自動変更は禁止。
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::Flags」
#
# 重要ルール:
# - 初期値は保守的にする（新機能はデフォルト false）
# - 本番影響があるものは人間承認後に true へ変更する
Rails.application.config.x.ledger_v2_flags = {
  # v2 Kernel が安定するまでは false。安定後に人間が true へ変更する。
  daily_runner:         false,
  weekly_runner:        false,
  health_snapshot:      false,
  ticket_creation:      false,
  artifact_generation:  false,

  # 以下は v2 初期では作らないもの。変更禁止。
  monthly_runner:   false,
  quarterly_runner: false,
  annual_runner:    false,
  auto_pr:          false,
  auto_merge:       false
}.freeze
