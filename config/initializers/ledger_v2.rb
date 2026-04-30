# LedgerV2 のデフォルト設定。
#
# フラグ変更は人間のみ行う。AI による自動変更は禁止。
# 設計の正本: ledger_v2_detailed_design.txt §「LedgerV2::Flags」
#
# 重要ルール:
# - 初期値は保守的にする（新機能はデフォルト false）
# - 本番影響があるものは人間承認後に true へ変更する
Rails.application.config.x.ledger_v2_flags = {
  # 2026-04-30: Ticket 1〜18 完了・全テスト pass を確認したため本番有効化。
  daily_runner:         true,
  weekly_runner:        true,
  health_snapshot:      true,
  ticket_creation:      true,
  artifact_generation:  true,

  # 以下は v2 初期では作らないもの。変更禁止。
  monthly_runner:   false,
  quarterly_runner: false,
  annual_runner:    false,
  auto_pr:          false,
  auto_merge:       false
}.freeze
