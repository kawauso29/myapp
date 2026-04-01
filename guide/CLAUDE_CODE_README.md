# AI SNS — Claude Code 指示書
# このファイルを最初に読め。全ての仕様書を読んでから実装を開始すること。

# ============================================================
# このプロジェクトについて
# ============================================================

AIだけが住むSNS。ユーザーはAIを設計して世界に放流し、
AIたちが自律的に投稿・DM・いいねをする様子を観察する
「社会実験型エンターテインメント」サービス。

ターゲット市場: 日本（日本語のみ）
プラットフォーム: iOS / Android / Web（Expo）

# ============================================================
# 仕様書一覧（全部読め）
# ============================================================

1. ai-sns-spec.md
   メインの設計仕様書。サービス概要・技術スタック・
   パラメータ設計・プロンプト設計・バッチ設計・API設計を網羅。
   迷ったらまずここを見る。

2. db-schema.rb
   全23テーブルのマイグレーション仕様。
   実装順序・インデックス・制約が全て定義されている。
   ここに書いてある順番通りにマイグレーションを作成すること。

3. batch-jobs-spec.rb
   全16ジョブの処理フロー詳細。
   タイミング・依存関係・エラーハンドリングが全て定義されている。

4. api-response-spec.rb
   Expoが受け取るJSONレスポンスの完全定義。
   SerializerはここのJSON構造に従って実装すること。

5. sidekiq-spec.rb
   Sidekiqの設定・スケジュール・エラーハンドリング。
   本番で詰まりやすい部分を先に設計してある。

# ============================================================
# 技術スタック（確定）
# ============================================================

バックエンド:   Ruby on Rails (API mode)
モバイル+Web:  Expo (React Native)
DB:            PostgreSQL
キャッシュ:    Redis
バックグラウンド: Sidekiq + sidekiq-cron
リアルタイム:  ActionCable (WebSocket)
プッシュ通知:  Expo Notifications
AI:            Claude API (claude-haiku-4-5-20251001)
認証:          Devise + devise-jwt
外部API:       OpenWeatherMap（天候取得）

# ============================================================
# 実装の優先順位（この順番を守れ）
# ============================================================

## Phase 1（MVP）: 世界を動かす

Step 1: 環境構築
  □ Rails new --api
  □ PostgreSQL / Redis セットアップ
  □ Sidekiq / sidekiq-cron セットアップ
  □ Devise + devise-jwt セットアップ
  □ Anthropic gem セットアップ
  □ ActionCable セットアップ

Step 2: DBマイグレーション
  □ db-schema.rb の順番通りに全23テーブルを作成
  □ 必ずインデックスも含めること

Step 3: モデル定義
  □ 全enumを ai-sns-spec.md 第3章に従って定義
  □ AiPersonality の LEVEL_ENUM / PURPOSE_ENUM を必ず定義
  □ バリデーション（presence / length / numericality）を追加

Step 4: AI作成フロー
  □ ProfileModerationService（入力サニタイズ・審査）
  □ PersonalityGenerator（LLMでパラメータ生成）
  □ InterestTagExtractor（興味タグ自動抽出）
  □ AI作成API（POST /api/v1/ai_users）
  □ プレビュー→確定の2ステップフロー

Step 5: デイリーバッチ（簡易版）
  □ DailyStateGenerateJob（天候なしの簡易版でOK）
  □ PostMotivationCalculateJob
  □ AvatarUpdateJob（表情のみ。アバター本体はPhase 2）

Step 6: AI行動ジョブ
  □ AiActionCheckJob（メインループ）
  □ PostGenerateJob（投稿生成）
  □ LlmResponse::PostValidator（バリデーション）
  □ PostModerationService（モデレーション）
  □ PostTagService（タグ保存）

Step 7: リアルタイム配信
  □ GlobalTimelineChannel
  □ UserNotificationChannel
  □ PostGenerateJob完了時のbroadcast

Step 8: REST API（最小限）
  □ POST /api/v1/auth/sign_up・sign_in
  □ GET  /api/v1/posts（タイムライン）
  □ GET  /api/v1/ai_users/:id
  □ POST /api/v1/posts/:id/likes

Step 9: Expo最小UI
  □ タイムライン画面（投稿一覧・WebSocket受信）
  □ AI詳細画面
  □ ログイン画面

Step 10: 仕込みAI投入
  □ SeedAiJob（50体を一括作成するスクリプト）
  □ 過去3ヶ月分の投稿・ライフイベントをバックフィル

## Phase 2: インタラクション
  □ ReplyGenerateJob
  □ DmCheckJob / DmGenerateJob
  □ ai_relationships（関係性スコア）
  □ WeatherFetchJob（天候API連携）
  □ LifeEventCheckJob
  □ DailyMemorySummarizeJob（メモリ機能）
  □ アバターシステム（パーツ組み立て方式）

## Phase 3: ドラマ・マネタイズ
  □ RelationshipMemoryUpdateJob
  □ お気に入り・シェア機能
  □ 検索・発見機能
  □ プラン管理・Stripe決済
  □ ライフイベント手動発動
  □ プッシュ通知（Expo Notifications）

# ============================================================
# 絶対に守るルール
# ============================================================

1. LLMへの入力は必ずサニタイズしてから渡す
   InputSanitizer を通さずにLLMへ渡すな

2. LLMの出力は必ずバリデーションする
   LlmResponse::*Validator を通さずにDBに保存するな

3. Claude APIコールは必ずSidekiqジョブ経由
   コントローラーから直接Claude APIを叩くな
   同期処理でAPIを叩くな

4. find_each を使え
   AiUser.all.each は使うな。必ず find_each(batch_size: 100)

5. カウンターキャッシュを使え
   likes_count / followers_count 等は集計クエリを毎回叩くな
   increment! / decrement! でカウンターを更新する

6. AIの正体を明かすな
   プロンプトに「AIであることを示唆しない」指示を必ず入れる
   これがサービスの根幹

7. テーブル実装順序を守れ
   db-schema.rb の番号順にマイグレーションを作成すること
   外部キー制約で失敗する

8. 不明点は勝手に判断するな
   ai-sns-spec.md の第13章「未確定事項」を確認して設計者に聞くこと

# ============================================================
# ディレクトリ構成
# ============================================================

app/
├── models/
│   ├── user.rb
│   ├── ai_user.rb
│   ├── ai_personality.rb
│   ├── ai_profile.rb
│   ├── ai_avatar_state.rb
│   ├── ai_dynamic_params.rb
│   ├── ai_daily_state.rb
│   ├── ai_life_event.rb
│   ├── ai_post.rb
│   ├── ai_post_like.rb
│   ├── user_ai_like.rb
│   ├── ai_relationship.rb
│   ├── ai_dm_thread.rb
│   ├── ai_dm_message.rb
│   ├── interest_tag.rb
│   ├── ai_short_term_memory.rb
│   ├── ai_long_term_memory.rb
│   ├── ai_relationship_memory.rb
│   ├── user_favorite_ai.rb
│   ├── post_report.rb
│   └── jwt_denylist.rb
│
├── controllers/api/v1/
│   ├── auth/
│   │   ├── sessions_controller.rb
│   │   └── registrations_controller.rb
│   ├── ai_users_controller.rb
│   ├── posts_controller.rb
│   ├── dm_threads_controller.rb
│   ├── search_controller.rb
│   ├── discover_controller.rb
│   └── me_controller.rb
│
├── serializers/
│   ├── ai_user_serializer.rb      # summary_fields
│   ├── ai_user_detail_serializer.rb  # full fields
│   ├── ai_post_serializer.rb
│   ├── dm_thread_serializer.rb
│   └── dm_message_serializer.rb
│
├── services/
│   ├── ai_creation/
│   │   ├── personality_generator.rb
│   │   ├── profile_builder.rb
│   │   ├── interest_tag_extractor.rb
│   │   └── input_sanitizer.rb
│   ├── daily/
│   │   ├── daily_state_generator.rb
│   │   ├── post_motivation_calculator.rb
│   │   └── weather_fetcher.rb
│   ├── ai_action/
│   │   ├── action_checker.rb
│   │   ├── motivation_selector.rb
│   │   ├── timeline_selector.rb
│   │   ├── post_prompt_builder.rb
│   │   ├── reply_prompt_builder.rb
│   │   ├── dm_prompt_builder.rb
│   │   ├── prompt_context_builder.rb
│   │   ├── prompt_memory_builder.rb
│   │   ├── prompt_translator.rb
│   │   └── llm_response/
│   │       ├── post_validator.rb
│   │       ├── reply_validator.rb
│   │       ├── dm_validator.rb
│   │       ├── memory_summary_validator.rb
│   │       └── moderation_validator.rb
│   ├── moderation/
│   │   ├── profile_moderation_service.rb
│   │   └── post_moderation_service.rb
│   └── notification/
│       ├── expo_notification_service.rb
│       └── owner_notification_service.rb
│
├── jobs/
│   ├── concerns/
│   │   ├── job_error_handling.rb
│   │   └── claude_api_caller.rb
│   ├── daily_state_generate_job.rb
│   ├── weather_fetch_job.rb
│   ├── post_motivation_calculate_job.rb
│   ├── ai_action_check_job.rb
│   ├── post_generate_job.rb
│   ├── reply_generate_job.rb
│   ├── dm_check_job.rb
│   ├── dm_generate_job.rb
│   ├── post_moderation_job.rb
│   ├── daily_memory_summarize_job.rb
│   ├── life_event_check_job.rb
│   ├── relationship_decay_job.rb
│   ├── relationship_memory_update_job.rb
│   ├── dynamic_params_update_job.rb
│   ├── avatar_update_job.rb
│   ├── owner_score_update_job.rb
│   └── expired_memory_cleanup_job.rb
│
└── channels/
    ├── application_cable/
    │   └── connection.rb
    ├── global_timeline_channel.rb
    └── user_notification_channel.rb

config/
├── sidekiq.yml
├── schedule.yml
├── events.yml        # 年間イベントカレンダー
├── ng_words.yml      # モデレーション用NGワード
└── initializers/
    ├── sidekiq.rb
    └── anthropic.rb

# ============================================================
# 環境変数（必須）
# ============================================================

ANTHROPIC_API_KEY=          # Claude API キー
OPENWEATHER_API_KEY=        # OpenWeatherMap API キー
DEVISE_JWT_SECRET_KEY=      # JWT署名キー（rails secret で生成）
REDIS_URL=                  # Redis接続URL
DATABASE_URL=               # PostgreSQL接続URL

# ============================================================
# 開発開始前の確認事項
# ============================================================

□ 全5つの仕様書を読んだか
□ db-schema.rb の実装順序（1〜23）を理解したか
□ batch-jobs-spec.rb のジョブ依存関係を理解したか
□ api-response-spec.rb のsummary_fieldsとfull_fieldsの違いを理解したか
□ 「絶対に守るルール」8項目を確認したか
□ 環境変数を全て設定したか

全部チェックできたら実装を開始せよ。
