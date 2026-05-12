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

  # 2026-05-03: Ticket 23 で Monthly dry_run を開始。MonthlyRunner は dry_run: true のみ許可。
  monthly_runner:   true,

  # 以下は v2 初期では作らないもの。変更禁止。
  quarterly_runner: false,
  annual_runner:    false,
  auto_pr:          false,

  # 2026-05-12: Phase C 最小実装。draft PR の CI 状態を読んで Event / metadata に記録する。
  # 読み取り専用で merge / deploy は行わないためデフォルト ON。
  sync_draft_pr_status: true,

  # Phase G-5（2026-05-07）: ALL PASS 14圧縮日維持を確認、AutoMerge 解除。
  # 逆戻り条件: StopCondition target_type "auto_merge" / "all" が active なら Flags.enabled? が false を返す。
  auto_merge:       true,

  # 2026-05-09: Ticket 31 EvaluateImprovement 実装。Ticket 解決後の指標改善追跡を有効化。
  # Event 記録のみで戦略変更なし。デフォルト ON（明示的に false で opt-out 可）。
  evaluate_improvement: true
}.freeze
