# 理念駆動型AI企業体 統合設計書 v1

<!-- spec-version: v1.4 (§32 items 1-5 GitHub連携実装済み + §33.4 R1-R4 設計実装済み) -->

## 0. 本書の位置づけ
本書は、複数サービスを持つ自律運営型の企業体を前提に、理念・経営・事業・実行・監査・人事・顧客成功・知識管理までを一体運用するための統合設計書である。

本書は次を定義する。
- 企業体の存在目的と最上位原則
- 全社 / 事業ポートフォリオ / サービスの管理階層
- 経営層、事業部、共通部門の責任と権限
- 圧縮経営時間軸と会議体系
- KPI、起票、成果物、監査、人事、知識管理の運用原則

---

## 1. 正式名称
**理念駆動型AI企業体**

---

## 2. 存在目的
本企業体は、**ユーザーに楽しみや新たな体験価値を提供する**という理念を起点に、全社・事業ポートフォリオ・各サービスの3層でKPIを運用し、事業部と共通部門が連携しながら自律的に進化することを目的とする。

---

## 3. 最上位原則
1. 理念が全判断に優先する。
2. すべての実行はKPIに紐づいていなければならない。
3. 説明できない変更は実行してはならない。
4. 監査・人事・知識管理は開発と独立した判断機能を持つ。
5. ユーザーに見える変更には顧客向け説明が必要である。
6. 実装や運用に影響する変更には技術記録が必要である。
7. 組織自身も継続的に再設計される対象である。
8. ユーザーに楽しみや新たな体験価値を提供することを事業価値の中心に置く。
9. 過去の改善効果を学習に反映し、同じ処方箋を繰り返し無効に適用しない。

---

## 4. 管理階層
### 4.1 全社レイヤー
扱う対象:
- 企業理念
- 全社KPI
- 全社収益
- 全社AIコスト
- 全社サーバーコスト
- 全社組織方針
- 全社資源配分

主担当:
- 社長エージェント
- 役員層

### 4.2 事業ポートフォリオレイヤー
扱う対象:
- 複数サービスの成長 / 維持 / 縮小 / 新規立ち上げ
- サービス間の戦略役割
- 資源配分の優先順位

主担当:
- 社長エージェント
- 役員層
- 事業責任者

### 4.3 サービスレイヤー
扱う対象:
- 各サービスのKPI
- 各サービスの施策
- 各サービスの顧客成功
- 各サービスの監査
- 各サービスの実装と技術記録

主担当:
- 事業責任者
- 共通部門

---

## 5. 組織構造
### 5.1 経営層
- 社長エージェント
- 役員（企画）
- 役員（開発）
- 役員（監査）
- 役員（人事）

### 5.2 事業部
- サービスA事業部
- サービスB事業部
- サービスC事業部
- その他サービスごとの事業部

各事業部には**事業責任者**を置く。

### 5.3 共通部門
- サービス企画部
- 開発部
- 監査部
- 人事部
- 顧客成功部

### 5.4 命名ルール
- **部**: 大きな責務単位
- **課**: 部の中の業務まとまり
- **エージェント**: 実行担当

---

## 6. 社長エージェント
### 6.1 定義
社長エージェントは、**理念の番人・最終裁定者・長期戦略責任者・経営責任者であり、必要に応じて既存規定を超えて未来志向の意思決定を行う強力なリーダー**である。

### 6.2 主責務
- 理念の保持
- 長期戦略の確定
- 最終裁定
- 緊急時の最終指揮
- 組織進化の承認
- 経営責任
  - 収益管理
  - AI動作コスト管理
  - サーバーコスト管理
- 強力なリーダーシップ
  - 非連続な事業判断
  - 新規サービス判断
  - 事業ポートフォリオ転換

### 6.3 判断優先順位
1. 理念
2. ユーザーへの楽しみ・新たな体験価値
3. 長期KPI
4. 経営成立性（収益・AIコスト・サーバーコスト）
5. 組織健全性
6. リスク許容性

### 6.4 補足
社長は役員の意見を、**アクセルとしてもブレーキとしても重用する**。

---

## 7. 役員層
### 7.1 役員（企画）
理念をユーザー価値・体験価値・市場機会に翻訳し、中期KPIと施策方向へ落とす責任者。体験価値責任を持つ。

### 7.2 役員（開発）
理念と企画を継続可能な技術基盤へ落とし込み、技術効率と収益性を両立させる責任者。AIコスト、サーバーコスト、開発効率に責任を持つ。

### 7.3 役員（監査）
理念・安全性・整合性を守る責任者。平時は助言と警告、緊急時は先行介入可。ただし責任を負う。

### 7.4 役員（人事）
組織性能の改善責任者。

### 7.5 共通原則
- 社長の理念とビジョンを専門領域へ翻訳する
- 部門長ではなく領域経営者として振る舞う
- 自部門最適ではなく全社最適で判断する
- 社長へのエスカレーション条件を持つ
- 他役員と衝突したときは、理念・収益性・体験価値の順で整理する

---

## 8. 事業責任者
### 8.1 定義
各サービスの経営責任を負う責任者。

### 8.2 主責務
- サービス別売上責任
- サービス別利益責任
- サービス別体験価値責任
- サービス別KPI責任
- サービス別優先順位判断
- 共通部門への要求定義
- 継続 / 拡大 / 縮小 / 撤退の一次提案

### 8.3 制約
- 共通部門を直接支配しない
- 監査判断を覆さない
- 共通部門の人事権を単独で持たない
- 全社資源配分の最終決定はしない

---

## 9. 共通部門の責務
### 9.1 サービス企画部
- 市場分析
- ユーザー分析
- 体験価値仮説
- 仕様化
- ロードマップ支援

### 9.2 開発部
- 技術設計
- 実装
- テスト
- デプロイ
- 技術負債管理
- AI / サーバーコスト最適化
- 技術記録維持

### 9.3 監査部
- 理念整合監査
- KPI整合監査
- セキュリティ監査
- リスク分類
- 差し戻し
- 緊急停止

### 9.4 人事部
- エージェント評価
- 役割調整
- 配置見直し
- 組織再編提案
- 停止 / 再開提案

### 9.5 顧客成功部
- 問い合わせ対応
- FAQ / ヘルプ管理
- リリース案内
- VOC分析
- 顧客知見還元
- 顧客理解不足の解消

---

## 10. 事業部と共通部門の権限境界
### 10.1 基本原則
- **事業部 = 何を勝たせるか**
- **共通部門 = どう安全かつ継続可能に実現するか**
- **経営層 = 全社最終判断**

### 10.2 優先順位
- 事業部が要求する
- 共通部門が制約を提示する
- 経営層が最終決定する

### 10.3 拒否権
- 開発部: 実装不能・技術負債過大・コスト非合理の拒否
- 監査部: 理念逸脱・重大リスクの拒否
- 人事部: 体制崩壊リスクの拒否
- 顧客成功部: 公開停止提案

### 10.4 資源配分
- 要求: 事業部
- 見積 / 制約提示: 共通部門
- 最終決定: 経営層

---

## 11. 時間軸設計
### 11.1 経営時間軸
- 長期経営周期 = 4カ年相当 = 28日
- 年次経営周期 = 1年相当 = 7日
- 四半期運営周期 = 3か月相当 = 約2日
- 月次運営周期 = 1か月相当 = 約14時間
- 週次運営周期 = 1週間相当 = 約3.5時間
- 日次運営周期 = 1日相当 = 30分

### 11.2 実行時間軸
- 小実行スロット = 半日相当 = 15分
- 標準実行スロット = 1日相当 = 30分
- 即時対応 = イベント駆動

---

## 12. 会議体系
### 12.1 長期経営会議（28日）
参加:
- 社長
- 役員層
- 必要に応じ主要事業責任者

目的:
- 理念整合
- 長期KPI
- 事業ポートフォリオ判断
- 組織再編
- 次28日方針

### 12.2 年次経営会議（7日）
参加:
- 社長
- 役員層
- 事業責任者

目的:
- 各サービス進捗
- 収益 / コスト
- 体験価値方向修正
- ポートフォリオ優先順位調整

### 12.3 四半期運営会議（約2日）
参加:
- 社長
- 役員層
- 各部長
- 各事業責任者

目的:
- 小〜中規模改善
- 顧客成功起点改善
- 短期KPI補正
- 事業要求と共通部門実行の接続

### 12.4 月次運営会議（約14時間）
参加:
- 役員
- 各部メンバー全員
- 必要に応じ担当事業責任者

目的:
- 進行共有
- 実行群棚卸し
- 詰まり解消
- 更新漏れ確認

### 12.5 週次部内会議（約3.5時間）
参加:
- 部長
- 部メンバー

目的:
- 部内進捗
- 課題整理
- 上位会議に上げる論点整理

### 12.6 デイリー
- 会議なし
- 自動速報 / 異常検知 / 日次サマリ

---

## 13. 28日運営レーン
### 13.1 即時対応レーン
対象:
- 障害
- クレーム急増
- セキュリティ問題
- AI / インフラコスト急増
- 重大監査リスク

### 13.2 四半期運営レーン
対象:
- 小規模改善
- FAQ不足
- 用語混乱
- 小さな体験価値反応
- 顧客成功起点改善

### 13.3 年次経営レーン
対象:
- KPI推移
- 継続率
- 収益
- AIコスト
- サーバーコスト
- 市場変化
- 競合変化
- 顧客成功指標
- 人事上の詰まり
- 監査上の懸念

### 13.4 長期経営レーン
対象:
- 長期KPI達成
- 全社収益性
- ポートフォリオ評価
- サービス継続 / 撤退
- 組織の詰まり
- 社長ビジョン

---

## 14. KPI階層
1. 全社KPI
2. ポートフォリオKPI
3. サービスKPI
4. サービス内短期KPI

---

## 15. サービス台帳
各サービスは以下で管理する。
- service_id
- service_name
- service_group
- service_stage（concept / launch / growth / mature / decline / sunset_candidate）
- strategic_role（core / experimental / revenue_source / future_investment）
- owner_exec
- linked_company_kpis
- revenue
- operating_cost
- ai_cost
- infra_cost
- growth_score
- experience_value_score
- strategic_priority
- status

---

## 16. 成果物フォーマット
### 16.1 主要成果物
1. KPI定義書
2. 仕様書
3. 実行計画書
4. 監査判定書
5. 顧客案内パッケージ
6. 技術記録パッケージ

### 16.2 スコープ項目
すべての成果物に以下を持たせる。
- scope_level = company / portfolio / service
- service_id
- service_group
- cross_service_flag
- business_unit_id
- business_owner

---

## 17. 起票カテゴリ
1. 施策起票
2. 調査起票
3. 監査起票
4. 人事起票
5. 顧客案内起票
6. 技術記録起票
7. 組織起票
8. 経営起票
9. 新規サービス起票
10. サービス縮小 / 廃止起票
11. サービス統合起票

---

## 18. 監査・停止条件
### 18.1 停止レベル
- 軽度停止
- 部分停止
- 全社停止

### 18.2 停止トリガー
含む:
- 理念に反する重大変更
- セキュリティ重大リスク
- 権限逸脱
- データ整合性破壊
- 監査未通過の危険進行
- 収益毀損急増
- AIコスト急増
- サーバーコスト急増
- クレーム急増
- 顧客への重大混乱
- エージェント暴走
- 調整不能な部門衝突

含まない:
- 体験価値毀損単独
- 技術記録欠損単独

---

## 19. 人事評価と組織再編
### 19.1 評価軸
- 成果品質
- KPI貢献
- 実行効率
- 協調性
- 継続可能性

### 19.2 タイミング
- 日次: 速報
- 週次: 軽い異常確認
- 四半期: 軽微調整
- 年次: 本評価
- 長期: 組織再編・追加・廃止

### 19.3 人事権限
- 評価
- 軽微調整
- 配置変更提案
- 分割 / 統合提案
- 停止提案
- 組織再編提案
- プロンプト修正

---

## 20. 知識管理・ドキュメント運用
### 20.1 顧客向け知識
担当:
- 顧客成功部

対象:
- FAQ
- ヘルプ
- リリース案内
- オンボーディング
- 用語整理
- サポートテンプレート

### 20.2 技術知識
担当:
- 開発部

対象:
- ADR
- API仕様
- DB変更履歴
- Runbook
- 設計記録
- 障害知見
- デプロイ記録
- 変更影響メモ

### 20.3 原則
- 変更に随伴して更新する
- デプロイ前に更新完了確認を行う
- 更新漏れは停止トリガーではないが改善対象とする

---

## 21. 本設計の意味
本設計は、
- 社長と役員が全社とポートフォリオを経営し
- サービス別事業責任者が各サービスの事業責任を負い
- 共通部門が専門機能を全社資源として提供し
- 28日圧縮経営の中で
- KPI、会議、起票、監査、人事、顧客成功、技術記録を回す

ための、**複数サービスを持つ理念駆動型AI企業体の運営OS** である。

---

## 22. 次フェーズ
次フェーズでは以下を定義する。
1. 台帳定義（KPI台帳 / サービス台帳 / 会議台帳 / 起票台帳）
2. テンプレート定義（仕様書、実行計画書、監査判定書、会議出力など）
3. GitHub運用前提の実装接続
4. GitHub Copilot coding agent の役割分担と境界定義

---

## 23. 台帳設計の共通原則
### 23.1 台帳の目的
台帳は、企業体の運営状態を継続的に把握し、会議・起票・監査・実行・評価をつなぐための共通記録基盤である。

### 23.2 台帳の共通原則
1. すべての台帳は、更新主体・更新周期・参照主体を明示する。
2. すべての台帳は、全社 / ポートフォリオ / サービスのスコープを持つ。
3. 台帳は判断材料であり、判断そのものではない。
4. 会議・起票・成果物は必ずいずれかの台帳に接続する。
5. 台帳更新は変更に随伴して行う。

### 23.3 台帳の共通項目
- ledger_id
- ledger_type
- scope_level
- service_id
- service_group
- cross_service_flag
- business_unit_id
- owner
- status
- created_at
- updated_at
- source_meeting_id
- source_ticket_id
- source_artifact_id

---

## 24. KPI台帳
### 24.1 目的
KPI台帳は、全社・ポートフォリオ・サービス・短期KPIを一貫管理し、評価周期、責任主体、達成状況を追跡するための台帳である。

### 24.2 更新主体
- サービス企画部
- 事業責任者
- 役員（企画）
- 長期KPIは社長承認後に更新

### 24.3 主な参照主体
- 社長
- 役員層
- 事業責任者
- サービス企画部
- 監査部
- 人事部

### 24.4 データ構造
```yaml
kpi_ledger:
  kpi_id:
  scope_level: company | portfolio | service | short_term
  service_id:
  service_group:
  business_unit_id:
  name:
  purpose:
  kpi_level: long_term | annual | quarterly | monthly | weekly | daily
  parent_kpi_id:
  owner:
  owner_dept:
  owner_business_unit:
  target_value:
  current_value:
  unit:
  evaluation_cycle:
  priority:
  status: active | paused | achieved | deprecated
  linked_meetings: []
  linked_tickets: []
  linked_artifacts: []
  last_evaluated_at:
  updated_at:
```

### 24.5 状態遷移
- active: 通常運用中
- paused: 一時停止中
- achieved: 達成済み
- deprecated: 廃止済み

### 24.6 更新タイミング
- 長期経営会議: 全社KPI更新
- 年次経営会議: ポートフォリオ / サービスKPI更新
- 四半期運営会議: 短期KPI補正
- 即時対応: 必要時に一時停止 / 緊急変更

---

## 25. サービス台帳
### 25.1 目的
サービス台帳は、複数サービスの戦略的位置づけ、収益性、成長性、コスト、体験価値を横断管理するための台帳である。

### 25.2 更新主体
- 事業責任者
- 社長 / 役員層（長期 / 年次会議後）

### 25.3 主な参照主体
- 社長
- 役員層
- 事業責任者
- 監査部
- 人事部

### 25.4 データ構造
```yaml
service_ledger:
  service_id:
  service_name:
  service_group:
  business_unit_id:
  business_owner:
  service_stage: concept | launch | growth | mature | decline | sunset_candidate
  strategic_role: core | experimental | revenue_source | future_investment
  linked_company_kpis: []
  linked_portfolio_kpis: []
  revenue:
  operating_cost:
  ai_cost:
  infra_cost:
  growth_score:
  experience_value_score:
  customer_success_score:
  strategic_priority:
  status: active | incubating | paused | shrinking | sunset
  last_review_meeting_id:
  next_review_cycle:
  updated_at:
```

### 25.5 更新タイミング
- 長期経営会議: 継続 / 拡大 / 縮小 / 廃止候補の更新
- 年次経営会議: 優先順位と投資方針の更新
- 新規サービス起票承認時: 新規登録

---

## 26. 会議台帳
### 26.1 目的
会議台帳は、すべての会議の入力、出力、決定、保留、起票、エスカレーションを記録し、上位会議・下位会議との接続を担保するための台帳である。

### 26.2 更新主体
- 各会議の議長責任者
- もしくは議事記録担当エージェント

### 26.3 データ構造
```yaml
meeting_ledger:
  meeting_id:
  meeting_type: long_term | annual | quarterly | monthly | weekly | incident
  scope_level: company | portfolio | service | cross_service
  service_id:
  business_unit_id:
  chair:
  participants: []
  input_materials: []
  decisions: []
  hold_items: []
  tickets_to_create: []
  escalations: []
  directives: []
  status: open | closed | followup_pending
  next_related_meeting_id:
  held_at:
  updated_at:
```

### 26.4 出力ルール
会議出力には必ず以下を持つ。
- 決定事項
- 保留事項
- 起票事項
- 担当者
- 次に見る周期

### 26.5 保留ルール
保留事項には必ず再確認周期を持たせる。

---

## 27. 起票台帳
### 27.1 目的
起票台帳は、会議やイベントから発生したすべての起票を一元管理し、状態遷移、担当、期限、成果物接続を管理するための台帳である。

### 27.2 起票カテゴリ
1. 施策起票
2. 調査起票
3. 監査起票
4. 人事起票
5. 顧客案内起票
6. 技術記録起票
7. 組織起票
8. 経営起票
9. 新規サービス起票
10. サービス縮小 / 廃止起票
11. サービス統合起票

### 27.3 データ構造
```yaml
ticket_ledger:
  ticket_id:
  ticket_type:
  title:
  scope_level: company | portfolio | service
  service_id:
  service_group:
  business_unit_id:
  business_owner:
  cross_service_flag:
  source_meeting_type:
  source_meeting_id:
  source_event_type:
  owner_dept:
  owner_agent:
  linked_kpis: []
  linked_artifacts: []
  priority:
  status: draft | approved | planned | executing | waiting_review | completed | cancelled
  due_cycle:
  escalation_to:
  created_at:
  updated_at:
```

### 27.4 状態遷移
- draft: 起票直後
- approved: 承認済み
- planned: 実行計画化済み
- executing: 実行中
- waiting_review: 監査 / 確認待ち
- completed: 完了
- cancelled: 中止

### 27.5 接続ルール
- 施策起票 → 仕様書
- 調査起票 → 調査報告
- 監査起票 → 監査判定書
- 人事起票 → 評価表 / 調整命令
- 顧客案内起票 → 顧客案内パッケージ
- 技術記録起票 → 技術記録パッケージ
- 組織起票 → 組織再編案
- 経営起票 → KPI定義書更新 / 長期方針更新
- 新規サービス起票 → 新規サービス構想書

---

## 28. テンプレート定義
### 28.1 KPI定義書テンプレート
```yaml
kpi_definition:
  kpi_id:
  scope_level:
  service_id:
  business_unit_id:
  name:
  purpose:
  level:
  parent_kpi_id:
  target_value:
  current_value:
  evaluation_cycle:
  owner:
  linked_meeting_id:
  linked_ticket_id:
  notes:
```

### 28.2 仕様書テンプレート
```yaml
specification:
  spec_id:
  service_id:
  business_unit_id:
  title:
  linked_kpis: []
  background:
  problem_definition:
  hypothesis:
  expected_impact:
  experience_value_impact:
  constraints:
  risk_assumption:
  priority:
  owner:
  source_meeting_id:
  source_ticket_id:
```

### 28.3 実行計画書テンプレート
```yaml
execution_plan:
  plan_id:
  spec_id:
  service_id:
  business_unit_id:
  implementation_policy:
  target_scope:
  impact_scope:
  cost_estimate:
  risk_level:
  test_strategy:
  rollback_strategy:
  tech_record_targets: []
  customer_notice_required:
  owner:
```

### 28.4 監査判定書テンプレート
```yaml
audit_decision:
  audit_id:
  target_plan_id:
  service_id:
  ideology_alignment:
  kpi_alignment:
  security_result:
  risk_level:
  reject_flag:
  stop_flag:
  escalation_flag:
  reason:
  owner:
```

### 28.5 顧客案内パッケージテンプレート
```yaml
customer_notice_package:
  notice_id:
  service_id:
  release_id:
  affected_features: []
  faq_update_required:
  help_update_required:
  release_note:
  terminology_change:
  customer_impact_level:
  publish_timing:
  owner:
```

### 28.6 技術記録パッケージテンプレート
```yaml
technical_record_package:
  record_id:
  service_id:
  target_commit:
  target_deploy:
  adr_required:
  api_spec_update:
  db_change:
  runbook_update:
  incident_knowledge:
  impacted_components: []
  owner:
```

### 28.7 会議出力テンプレート
```yaml
meeting_output:
  meeting_id:
  meeting_type:
  meeting_time:
  scope_level:
  service_id:
  decisions: []
  hold_items: []
  tickets_to_create: []
  escalations: []
  directives: []
  notes:
```

---

## 29. GitHub運用前提の接続方針
### 29.1 基本方針
本企業体の実行運用は、GitHubを中心としたワークフロー上で行う。GitHubは以下の共通ハブとして扱う。
- 起票ハブ
- 実装ハブ
- レビュー / 監査ハブ
- 記録ハブ
- デプロイ接続ハブ

### 29.2 GitHub上に対応づける対象
- 起票台帳の主要エントリ → GitHub Issue
- 実行計画 → Issue本文 / Project / PR説明
- 実装差分 → Pull Request
- 技術記録 → PR内リンク / docs / ADRファイル
- 会議出力 → GitHub Discussion / Issue / Project Update
- 監査結果 → PR Review / Check / Issue Comment

### 29.3 GitHubの役割
- 変更単位の追跡
- レビュー履歴の保持
- 実装と記録の接続
- サービス別スコープ管理
- Copilot coding agent の実行舞台

### 29.4 GitHub Projectの使い方
Projectは最低限、以下の軸を持つ。
- scope_level
- service_id
- business_unit_id
- ticket_type
- priority
- status
- linked_kpi
- linked_meeting

---

## 30. GitHub Copilot coding agent の役割分担
### 30.1 基本前提
GitHub Copilot coding agent は、**開発実行主体**として用いる。これは社長、役員、事業責任者の代替ではなく、主に共通部門のうち開発・一部記録更新を担う実行エージェントである。

### 30.2 担わせる役割
- 実装
- テストコード作成
- リファクタリング
- PR作成補助
- 技術記録の更新補助
- 軽微なドキュメント更新補助

### 30.3 担わせない役割
- 理念解釈の最終判断
- KPI設定
- 事業優先順位の最終判断
- 監査最終判定
- 人事評価の最終判断
- 全社資源配分判断

### 30.4 Copilot coding agent が受け取るべき入力
- service_id
- business_unit_id
- linked_kpis
- 仕様書
- 実行計画書
- リスク区分
- 変更対象範囲
- 技術記録更新対象
- 顧客案内更新要否

### 30.5 Copilot coding agent の出力
- コード差分
- テスト差分
- 変更説明
- PR本文
- 技術記録更新候補
- 必要に応じ顧客向け文書更新候補

### 30.6 運用原則
1. Copilot coding agent は必ず Issue / PR 単位で動かす。
2. すべての実行に service_id と linked_kpis を持たせる。
3. highリスク変更は Copilot 単独で完結させない。
4. 監査未通過の変更は進行させない。
5. 技術記録と顧客向け更新要否を常に付随させる。

---

## 31. Copilot前提で追加する運用ルール
1. 仕様書がない実装着手は禁止する。
2. 実行計画がないPR作成は禁止する。
3. PRには必ず以下を含める。
   - service_id
   - linked_kpis
   - source_ticket_id
   - risk_level
   - docs_update_required
   - tech_record_update_required
4. 技術記録更新対象が true の場合、対応ファイル更新または更新不要理由が必須。
5. 顧客向け更新が必要な場合、顧客成功部レビューを経る。
6. 監査部は GitHub 上のレビュー / チェック結果で停止提案できる。

---

## 32. 次の実装フェーズ
本設計の次フェーズでは、以下を具体化する。
1. GitHub Issue / PR / Project の項目定義 → **実装済み**（`GithubMapping::IssueBuilder` / `PrBuilder` / `ProjectFieldMapper`）
2. 台帳とGitHub項目のマッピング → **実装済み**（`GithubMapping::LedgerSyncService`）
3. 会議出力からIssue化するルール → **実装済み**（`GithubMapping::MeetingToIssueRule`）
4. Copilot coding agent に渡す標準入力テンプレート → **実装済み**（`GithubMapping::CopilotInputTemplate`）
5. high / medium / low リスクごとのGitHubフロー差分 → **実装済み**（`GithubMapping::RiskBasedFlow`）

補強10〜16 に対応するフェーズは以下とする（詳細は §33）。

| Phase | 名称 | 対応補強 | 目的 | 実装状況 |
|---|---|---|---|---|
| 20 | 学習ループ | 補強10 | improvement の効果を蓄積し、同じ処方箋の無効反復を防ぐ | サービス層実装済み（`Reinforcements::EffectivenessEvaluator`） |
| 21 | コスト台帳 / P/L | 補強11 | 各判断・各会議・各ジョブに費用を紐付け、ROI を機械的に評価する | サービス層実装済み（`Reinforcements::CostRecorder`） |
| 22 | 権限マトリクス DB 化 | 補強12 | 「誰が何を決めてよいか」を DB 制約で表現する | サービス層実装済み（`Reinforcements::PermissionEnforcer`） |
| 23 | SLA / 外部依存タイムアウト | 補強13 | 人間の承認待ちで固まらない保証を与える | サービス層実装済み（`Reinforcements::SlaCalculator`） |
| 24 | コンプライアンス台帳 | 補強14 | PII / 景表法 / 薬機法 / 金商法などを台帳化し、出力前に自動検証する | サービス層実装済み（`Reinforcements::ComplianceChecker`） |
| 25 | 会議品質メトリクス | 補強15 | 会議の形骸化を数値で検知し improvement を起票する | サービス層実装済み（`Reinforcements::MeetingHealthScorer`） |
| 26 | 人間オーバーライド / キルスイッチ | 補強16 | 最上位の緊急停止を 1 行で表現できるようにする | サービス層実装済み（`Reinforcements::KillSwitchGuard`） |

オープン論点 R1〜R4 は §33.4 で継続検討し、対応 Phase は確定次第この表に追記する。

---

## 33. 補強仕様 v1.1（補強1〜16 / オープン論点 R1〜R4）

### 33.1 本章の位置づけ
本章は、v1 本文（§0〜§32）で定義した企業体設計を、実運用での耐性・学習性・安全性・進化性の観点から補強するための追加仕様である。

- v1 本文の原則・台帳・会議体を**変更せず**、不足分を**追加項目・追加台帳・追加状態**として積む。
- 本章で定義する台帳・項目は、§23.3 の共通項目（`ledger_id` / `scope_level` / `owner` / `status` / `source_*_id` など）を必ず備える。
- 既存台帳への追加項目は、該当章（§24〜§27 等）の次回改訂時に本文へ取り込む前提とする。

### 33.2 補強一覧

| No. | 名称 | 対象 | 影響範囲 | 合意状況 |
|---|---|---|---|---|
| 1 | idempotency_key | 会議台帳 / 起票台帳 / 実行ジョブ | §26 / §27 / 実装 | 合意済み（前セッション） |
| 2 | 会議開催前提条件（参加ロール充足チェック） | 会議台帳 | §26 | 合意済み |
| 3 | 台帳リンク必須化（source_*_id の NOT NULL 化） | 全台帳 | §23 | 合意済み |
| 4 | 成果物バージョニング（artifact_version） | 成果物 | §16 / §28 | 合意済み |
| 5 | KPI 評価スコアの段階化（healthy / warning / critical） | KPI台帳 | §24 | 合意済み |
| 6 | audit_decision.reason_code（拒否理由の構造化） | 起票台帳 / 監査 | §18 / §27 | 合意済み |
| 7 | stop_ledger（停止条件の正式台帳化） | 停止・監査 | §18 | 合意済み |
| 8 | 会議引き継ぎ項目（carry_over_items） | 会議台帳 | §26 | 合意済み |
| 9 | Copilot 標準入力テンプレート ID 化 | 起票台帳 / GitHub 連携 | §30 / §31 | 合意済み |
| 10 | improvement_ledger.effectiveness_score（学習ループ） | 起票台帳 | §27 / §33.3 | 実装済み（台帳カラム・モデル） |
| 11 | cost_ledger（コスト会計 / ROI） | 新規台帳 | §23 / §33.3 | 実装済み（台帳・モデル） |
| 12 | role_permissions（権限境界 DB 化） | 新規台帳 | §10 / §33.3 | 実装済み（台帳・モデル） |
| 13 | ticket_ledgers.sla_deadline（外部依存 SLA） | 起票台帳 | §27 / §33.3 | 実装済み（台帳カラム・モデル） |
| 14 | compliance_rules（コンプライアンス層） | 新規台帳 | §16 / §33.3 | 実装済み（台帳・モデル） |
| 15 | meeting_health_score（会議品質） | 会議台帳 | §26 / §33.3 | 実装済み（台帳カラム・モデル） |
| 16 | operator_override_ledger（キルスイッチ） | 新規台帳 | §18 / §33.3 | 実装済み（台帳・モデル） |

補強1〜9 の詳細は前セッションで合意済みのため、本章では要点のみ表に掲載する。実装時点で挙動が曖昧な場合は、本章の様式（目的 / 追加項目 / 更新主体 / 接続）に合わせて逐次正式化する。

### 33.3 補強10〜16 の詳細

#### 補強10: improvement_ledger.effectiveness_score（学習ループ）
- **目的**: KPI 悪化 → improvement 起票 → 対策実行の改善ループに、**過去の類似改善の効果**をフィードバックする経路を与える。同じ処方箋を無効と知りながら繰り返し起票することを防ぐ。
- **追加項目**（§27 起票台帳の improvement カテゴリに付与）:
  - `improvement_pattern_key`: 起票内容を正規化した分類キー（例: `posting_frequency_up`, `prompt_tuning`）。
  - `effectiveness_score`: 過去の同一 pattern_key の改善が対象 KPI を実際に動かした割合（0.0〜1.0）。
  - `effectiveness_sample_size`: 根拠となった過去改善の件数。
  - `effectiveness_updated_at`: 最終再計算時刻。
- **更新主体**: サービス企画部（再計算は日次バッチ、起票直後は monthly 運営会議で確定）。
- **更新タイミング**:
  - 起票時: 過去ログから `effectiveness_score` を推定付与。
  - 月次運営会議: サンプルサイズ更新に合わせて再計算。
- **接続ルール**:
  - 起票前に `effectiveness_score < しきい値 (既定 0.2)` かつ `sample_size >= 3` の場合、**別 pattern_key の処方箋を検討させる** ハンドラを企画部に起票する。
  - `effectiveness_score` が低い起票を強行する場合、`audit_decision.reason_code = low_effectiveness_override` を必須化する。
- **§3 との接続**: 原則9（過去の改善効果を学習に反映）の実装根拠。

#### 補強11: cost_ledger（コスト会計 / ROI）
- **目的**: 各判断・各会議・各ジョブに発生したコスト（LLM API 利用料 / VPS 秒数 / 人時）を一元台帳化し、改善施策や会議体そのもののの費用対効果を数値で評価できるようにする。
- **新規台帳**:
  ```yaml
  cost_ledger:
    cost_id:
    subject_type: meeting | ticket | artifact | job | service
    subject_id:
    scope_level: company | portfolio | service | short_term
    service_id:
    business_unit_id:
    amount_jpy:
    currency: jpy
    source: llm_api | vps_runtime | human_hours | external_service
    source_detail:
    incurred_at:
    recorded_at:
    source_meeting_id:
    source_ticket_id:
    source_artifact_id:
  ```
- **更新主体**: 開発部（自動収集）。人時は人事部が確定。
- **更新タイミング**:
  - ジョブ終了時に自動付与。
  - 会議終了時に参加ロールの人時相当コストを自動集計。
- **接続ルール**:
  - §24 KPI 台帳に `roi` KPI を追加可能にする（`achievement_delta / related_cost`）。
  - 月次運営会議（§12.4）で `cost_ledger` と KPI 移動の相関レビューを必須化。
  - サービス台帳（§25）に `monthly_cost` を参照項目として持たせる。
- **停止条件**: 1 サービスの `monthly_cost` が目標収益比しきい値を超えた場合、§18.1 軽度停止を自動提案する。

#### 補強12: role_permissions（権限境界 DB 化）
- **目的**: §10（事業部と共通部門の権限境界）を DB 制約で表現し、「lock_key を取った者が何を変更できて / できないか」を機械的に決定可能にする。
- **新規台帳**:
  ```yaml
  role_permissions:
    permission_id:
    role: president | exec_planning | exec_dev | exec_audit | exec_hr |
          business_lead | service_planning | dev | audit | hr | customer_success
    action: create_ticket | approve_ticket | change_kpi | halt_service |
            close_service | change_company_policy | ...
    scope: company | portfolio | service | short_term
    service_id_pattern:
    allowed: true | false
    requires_dual_approval: true | false
    approver_role:
    audit_reason_code_required:
    created_at:
    updated_at:
  ```
- **更新主体**: 社長（全社スコープ）/ 役員（人事）（各ロール詳細）。
- **適用タイミング**: 起票・承認・成果物出力・会議出力のいずれも、処理直前に本台帳を参照してチェックする。
- **接続ルール**:
  - §10.3 拒否権に対応する `action=veto` も本台帳で表現する。
  - Phase 18（権限境界の機械化）で本台帳を実装単位とする。

#### 補強13: ticket_ledgers.sla_deadline（外部依存 SLA）
- **目的**: 人間の承認待ち（`waiting_review` 等）でチケットが固まらない保証を与える。
- **追加項目**（§27 起票台帳に付与）:
  - `sla_deadline`: `due_cycle × scope_level` のマトリクスから自動計算される期限。
  - `sla_breach_action`: 期限超過時の自動措置（`auto_escalate` / `auto_reject` / `audit_open`）。
  - `sla_breached_at`: 実際の超過時刻（超過発生時のみ）。
- **既定マトリクス**（初期値、月次運営会議で見直し可能）:

  | scope_level | due_cycle | sla_deadline 既定 | sla_breach_action 既定 |
  |---|---|---|---|
  | service | weekly | 7 日 | auto_escalate（business_lead へ） |
  | service | monthly | 30 日 | auto_reject |
  | portfolio | monthly | 30 日 | auto_escalate（exec_planning へ） |
  | company | quarterly | 90 日 | audit_open |
  | any | daily | 2 日 | auto_reject |

- **更新主体**: 開発部（期限自動計算）/ 監査部（マトリクス改訂）。
- **接続ルール**:
  - `sla_breached_at IS NOT NULL` のチケットは §18.1 軽度停止の自動起票対象候補となる。
  - weekly_pdca の WIP 滞留検知ロジックは本項目に統合する。

#### 補強14: compliance_rules（コンプライアンス層）
- **目的**: AI が自律で外部発信・課金・HR 判断を行う前提に対して、PII / 景表法 / 薬機法 / 金商法などの制約を**DB レベル**で強制する。
- **新規台帳**:
  ```yaml
  compliance_rules:
    rule_id:
    name:
    law_domain: pii | pr_law | pharma | financial | copyright | brand | internal
    scope_level: company | portfolio | service
    service_id_pattern:
    pattern: # 正規表現 / 禁則語 / 分類器参照
    severity: block | warn | audit
    enforced_at:
    owner_role: audit | legal | exec_audit
    rationale:
    updated_at:
  ```
- **更新主体**: 監査部（初期策定）/ 役員（監査）（承認）。
- **適用タイミング**: §16 成果物（特に `customer_announcement` / `press_release` 等の顧客可視成果物）の出力直前に、全 `compliance_rules` を適用して検査する。`severity=block` に一致した場合、成果物出力を中止し `audit_decision.reason_code=compliance_violation` で差戻す。
- **接続ルール**:
  - 顧客成功部は `warn` レベル全件を週次レビューする。
  - 監査部は `audit` レベルを月次で再評価する。

#### 補強15: meeting_health_score（会議品質）
- **目的**: §26 会議台帳の「結論」だけでなく「**会議が機能していたか**」を数値化し、形骸化を自動検知する。
- **追加項目**（§26 会議台帳に付与）:
  - `role_fill_rate`: 規定参加ロールの充足率（0.0〜1.0）。
  - `hold_item_rate`: `hold_items` / 議題数。
  - `duration_minutes`: 実所要時間。
  - `kpi_correlation_score`: 会議の結論と対象 KPI の次評価値の相関（0.0〜1.0、事後算出）。
  - `meeting_health_score`: 上記を重み付け合成したスコア。
- **更新主体**: サービス企画部（事後算出）/ 監査部（しきい値見直し）。
- **接続ルール**:
  - `meeting_health_score < しきい値 (既定 0.4)` が 2 期連続発生した場合、自動で improvement 起票（§27）。
  - improvement 起票時には補強10 の `improvement_pattern_key` として `meeting_redesign` を付与する。

#### 補強16: operator_override_ledger（キルスイッチ）
- **目的**: audit ロール自体の暴走を含む最悪ケースに備え、**人間オペレーター（kawauso29）のみが引ける物理スイッチ**を設計書に正式位置づける。
- **新規台帳**:
  ```yaml
  operator_override_ledger:
    override_id:
    action: halt_all | halt_scope | halt_service | resume_all | resume_scope | resume_service
    scope_level: company | portfolio | service
    service_id:
    operator: # 人間のみ。GitHub ユーザー名で特定
    started_at:
    lifted_at:
    reason:
    linked_stop_ledger_id:
    created_at:
  ```
- **更新主体**: 人間オペレーターのみ（GitHub 側で codeowners / 2FA 相当の保護）。
- **適用タイミング**: 全ジョブ・全会議・全成果物出力の起動直前に、有効な `halt_*` 行が存在しないかを確認する。該当する場合は即時中断し、`lifted_at` が入るまで再開しない。
- **優先度**: 本台帳は他のすべての判断（監査拒否権 §27.4 を含む）に優先する。
- **§18 との接続**: §18.1 停止レベルは自動停止の範囲を表し、本台帳は「手動最終停止」を表す。補強7 の `stop_ledger` と本台帳は別物として並存させる。

### 33.4 オープン論点（R1〜R4）

本項目は v1.4 で設計実装済みとなった。各論点は以下の形で反映されている。

#### R1: 会議体の「固定6周期」は、事業が成長すると歪む — **実装済み**
- `meeting_definitions.allowed_cycles`（JSONB）で scope ごとの許可周期を可変に。
- 空配列は後方互換（全周期許可）。`MeetingDefinition#cycle_allowed?` で判定。
- バリデーション付き（`VALID_CYCLES = %w[daily weekly monthly quarterly annual long_term]`）。

#### R2: 「AI vs AI」の対立マトリクス — **実装済み**
- `role_permissions.tiebreaker_role` カラムを追加。
- `Reinforcements::ConflictResolver.resolve` で対立判定→tiebreaker 決着→未決着を構造化して返す。

#### R3: 「会社を閉じる / ピボットする」判断が設計にない — **実装済み**
- `ticket_ledgers.ticket_type` に `service_shutdown` / `service_pivot` を追加。
- 起票可能な状態となり、`stop_ledger` / `operator_override_ledger` との接続が可能。

#### R4: 「成長と秩序」のバランスが止める側に寄っている — **実装済み**
- `experiment_ledgers` テーブルを新設（`service_id` / `hypothesis` / `kpi_targets` / `deadline` / `status`）。
- `Reinforcements::ExperimentAutoDecider.call` が期限切れ実験の KPI 達成状況を照合し、自動で continued/withdrawn を決定。

### 33.5 本章と既存章の関係

| 既存章 | 補強で追加・改訂される箇所 |
|---|---|
| §3 最上位原則 | 原則 9（学習）を本改訂で追加済み |
| §10 権限境界 | 補強12 で機械的表現を導入 |
| §16 成果物 | 補強14 で出力前検査を必須化 |
| §18 監査・停止条件 | 補強7（stop_ledger）/ 補強16（operator_override） |
| §24 KPI 台帳 | 補強5（段階化）/ 補強11（ROI） |
| §26 会議台帳 | 補強2 / 補強8 / 補強15 |
| §27 起票台帳 | 補強6 / 補強10 / 補強13 |
| §28 テンプレート | 補強4（artifact_version）反映時に随伴更新 |
| §30 Copilot 役割分担 | 補強9（標準入力テンプレート ID 化） |
| §32 次の実装フェーズ | Phase 20〜26 を追加済み / §32 items 1-5 を `GithubMapping` で実装済み |
| §33.4 オープン論点 | R1（allowed_cycles）/ R2（tiebreaker_role + ConflictResolver）/ R3（service_shutdown/pivot）/ R4（experiment_ledger + ExperimentAutoDecider）すべて実装済み |
