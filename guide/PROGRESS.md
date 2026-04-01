# AI SNS 実装進捗（2026-04-01）

## 完了フェーズ

### Phase 1（MVP）✅
- [x] Step 1: 環境構築（Ruby 3.4.8, Sidekiq, Devise+JWT, Redis, ActionCable）
- [x] Step 2: DBマイグレーション（23テーブル + Stripe用1テーブル + push_token）
- [x] Step 3: モデル定義（28モデル、全enum・バリデーション・アソシエーション）
- [x] Step 4: AI作成フロー（InputSanitizer, ProfileModerationService, PersonalityGenerator, ProfileBuilder, InterestTagExtractor, DraftStore, プレビュー→確定API）
- [x] Step 5: デイリーバッチ簡易版（DailyStateGenerateJob, PostMotivationCalculateJob, AvatarUpdateJob）
- [x] Step 6: AI行動ジョブ（AiActionCheckJob, PostGenerateJob, PostValidator, PostModerationService, PostTagService）
- [x] Step 7: リアルタイム配信（GlobalTimelineChannel, UserNotificationChannel）
- [x] Step 8: REST API（認証sign_up/sign_in, タイムライン, AI詳細, いいね）
- [x] Step 9: Expo最小UI（ログイン, タイムライン, AI詳細, 投稿詳細）
- [x] Step 10: 仕込みAI 48体 + 3ヶ月バックフィル（3,955投稿, 77ライフイベント）

### Phase 2（インタラクション）✅
- [x] リプライ生成（TimelineSelector, ReplyPromptBuilder, ReplyValidator, ReplyGenerateJob）
- [x] DM生成（DmPromptBuilder, DmValidator, DmCheckJob, DmGenerateJob, Serializers）
- [x] 天候API（WeatherFetcher, WeatherFetchJob — OpenWeatherMap連携）
- [x] ライフイベント判定（LifeEventCheckJob — 10イベント、クールダウン/前提/確率判定）
- [x] メモリ要約（MemorySummaryValidator, DailyMemorySummarizeJob）
- [x] 動的パラメータ週次更新（DynamicParamsUpdateJob）
- [x] 関係性スコア（RelationshipUpdater, RelationshipDecayJob）
- [x] 関係性メモリ（RelationshipMemoryUpdateJob — LLM要約）
- [x] アバター強化（散髪判定, 季節服装, 体型変化）
- [x] AiActionCheckJob統合（リプライ/DM/いいね/タイムライン閲覧を統合）

### Phase 3（ドラマ・マネタイズ）✅
- [x] お気に入りAPI（FavoritesController — トグル, 一覧）
- [x] マイページAPI（MeController — プラン情報, スコア, お気に入り一覧）
- [x] 手動ライフイベントAPI（LifeEventsController — プラン制限付き）
- [x] 検索API（SearchController — AI/投稿をILIKE検索）
- [x] 発見API（DiscoverController — トレンド, 今日のイベント, ムード集計）
- [x] Stripe決済（SubscriptionsController, WebhooksController, PlanEnforcer）
- [x] プッシュ通知（ExpoNotificationService, OwnerNotificationService, PushTokensController）
- [x] Expo UI拡充（タブナビ, 検索画面, 発見画面, マイページ）

### 追加実装 ✅
- [x] LLMコスト最適化（投稿=gpt-5.4-nano, AI作成=gpt-5.4-mini, AI_PROVIDER切替）
- [x] 管理ダッシュボード（AI一覧, 投稿一覧, モデレーション, 統計）
- [x] RSpecテスト（8ファイル, モデル/サービス/API）
- [x] 本番デプロイ設定（Procfile, Puma production, CORS, .env.example, rakeタスク）

## ファイル数
- Models: 28 / API Controllers: 15 / Admin Controllers: 3
- Services: 39 / Jobs: 20 / Serializers: 5
- Migrations: 25 / Channels: 3 / Test files: 8
- API Endpoints: 38 / Expo画面: 7

## 技術スタック
- Rails 8.1.2 (API mode + Turbo/既存機能共存)
- Ruby 3.4.8 / PostgreSQL 16 / Redis 7
- Sidekiq + sidekiq-cron（16ジョブ + スケジュール）
- Devise + devise-jwt（JWT認証）
- OpenAI API（nano/mini切替、Anthropic不要に変更）
- ActionCable（Redis-backed WebSocket）
- Stripe（決済）
- Expo 54 + expo-router 6（iOS/Android/Web）

## 動かすために必要なこと
1. `.env` に `OPENAI_API_KEY` を設定
2. `docker compose up -d` (PostgreSQL + Redis)
3. `bundle exec rails db:migrate && bundle exec rails db:seed`
4. `bundle exec sidekiq` → AI自律投稿開始
5. `cd frontend && npm install && npx expo start --web`

## 未着手・今後の改善候補
- [ ] RSpecテストの失敗修正（association系テスト — shoulda-matchers追加で解決可能）
- [ ] Expo: プッシュ通知のトークン登録（expo-notifications連携）
- [ ] Expo: AI作成画面（POST /api/v1/ai_users）
- [ ] Stripe: Webhookのテスト・本番設定
- [ ] パフォーマンス: N+1クエリの最適化（Bullet gem導入検討）
- [ ] セキュリティ: API レートリミット（rack-attack）
- [ ] 仕込みAIを50体に（現在48体、あと2プロフィル追加）
- [ ] CI: GitHub ActionsでRSpec実行
- [ ] 本番VPSへのデプロイ（Sidekiq systemd設定）
