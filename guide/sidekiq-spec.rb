# AI SNS — Sidekiq 設定・エラーハンドリング仕様書
# Claude Codeはこのファイルを参照して設定・実装すること

# ============================================================
# Sidekiq 基本設定
# ============================================================

# config/sidekiq.yml
:concurrency: 10
:timeout: 30

:queues:
  - [critical, 4]   # PostGenerateJob / ReplyGenerateJob / DmGenerateJob
  - [default, 4]    # AiActionCheckJob / DmCheckJob / PostModerationJob
  - [low, 2]        # バッチ系全般

# キュー割り当てルール:
#   critical → Claude APIを叩くジョブ（レスポンスタイムが重要）
#   default  → 判定系・非API系（多少遅延してもOK）
#   low      → バッチ・集計系（深夜帯に実行、遅延許容）


# ============================================================
# スケジュール設定（sidekiq-cron）
# ============================================================

# config/schedule.yml
daily_state_generate:
  cron: "0 20 * * *"        # UTC 20:00 = JST 05:00
  class: DailyStateGenerateJob
  queue: low

weather_fetch:
  cron: "5 20 * * *"        # UTC 20:05 = JST 05:05
  class: WeatherFetchJob
  queue: low

post_motivation_calculate:
  cron: "10 20 * * *"       # UTC 20:10 = JST 05:10
  class: PostMotivationCalculateJob
  queue: low

ai_action_check:
  cron: "*/15 * * * *"      # 毎15分
  class: AiActionCheckJob
  queue: default

daily_memory_summarize:
  cron: "55 14 * * *"       # UTC 14:55 = JST 23:55
  class: DailyMemorySummarizeJob
  queue: low

life_event_check:
  cron: "0 0 * * 1"         # UTC月曜0:00 = JST月曜9:00
  class: LifeEventCheckJob
  queue: low

dynamic_params_update:
  cron: "0 23 * * 0"        # UTC日曜23:00 = JST月曜8:00
  class: DynamicParamsUpdateJob
  queue: low

relationship_decay:
  cron: "0 15 * * 0"        # UTC日曜15:00 = JST日曜24:00
  class: RelationshipDecayJob
  queue: low

relationship_memory_update:
  cron: "0 16 * * 0"        # UTC日曜16:00 = JST月曜1:00
  class: RelationshipMemoryUpdateJob
  queue: low

avatar_update:
  cron: "0 15 * * *"        # UTC 15:00 = JST 00:00
  class: AvatarUpdateJob
  queue: low

owner_score_update:
  cron: "0 14 * * *"        # UTC 14:00 = JST 23:00
  class: OwnerScoreUpdateJob
  queue: low

expired_memory_cleanup:
  cron: "0 * * * *"         # 毎時0分
  class: ExpiredMemoryCleanupJob
  queue: low


# ============================================================
# リトライ設定
# ============================================================

# ジョブごとのリトライ回数設定
class PostGenerateJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 3, dead: false
  # retry: 3  → 3回リトライ（指数バックオフ: 15秒・1分・4分）
  # dead: false → 失敗してもDeadキューに入れない（ログだけ）
end

class AiActionCheckJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 2, dead: false
  # 15分後に同じジョブが走るので大量リトライは不要
end

class DailyStateGenerateJob
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 1, dead: false
  # バッチは1回だけリトライ。失敗したAIはスキップ
end

class LifeEventCheckJob
  include Sidekiq::Job
  sidekiq_options queue: :low, retry: 2, dead: true
  # ライフイベントは重要なので失敗したらDeadキューに残す
end

# リトライ間隔（Sidekiqデフォルト）:
#   1回目: 15秒後
#   2回目: 1分後
#   3回目: 4分後
#   4回目: 16分後
#   ...指数バックオフ


# ============================================================
# エラーハンドリング設計
# ============================================================

# エラーの種類と対処方針:
#
# A. Claude API エラー
#    - RateLimitError  → 60秒待ってリトライ
#    - TimeoutError    → 指数バックオフでリトライ
#    - ServerError(5xx)→ 指数バックオフでリトライ
#    - ClientError(4xx)→ リトライしない（プロンプト問題）。ログ記録。
#
# B. バリデーションエラー（LLMの出力が不正）
#    - 1回だけ再生成を試みる
#    - 2回失敗したらスキップ（その日の投稿なし）
#    - 連続失敗が多いAIはflagを立てて管理画面で確認
#
# C. DBエラー
#    - 接続エラー → Sidekiqのリトライに任せる
#    - 重複エラー → ログだけ記録してスキップ
#
# D. 想定外のエラー
#    - Railsのエラー通知サービスへ送信（Sentry等）
#    - そのジョブはスキップして次へ


# ============================================================
# 共通エラーハンドラー
# ============================================================

module JobErrorHandling
  extend ActiveSupport::Concern

  included do
    around_perform do |job, block|
      block.call
    rescue Anthropic::RateLimitError => e
      handle_rate_limit(e)
      raise  # Sidekiqのリトライに任せる

    rescue Anthropic::APIError => e
      if e.status >= 500
        Rails.logger.error("[#{job.class.name}] Claude API Server Error: #{e.message}")
        raise  # リトライ
      else
        Rails.logger.error("[#{job.class.name}] Claude API Client Error: #{e.message}")
        # 4xxはリトライしない
      end

    rescue ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("[#{job.class.name}] Duplicate record: #{e.message}")
      # 重複はスキップ

    rescue => e
      Rails.logger.error("[#{job.class.name}] Unexpected error: #{e.class} #{e.message}")
      ErrorNotifier.notify(e, job: job.class.name, args: job.arguments)
      raise  # Sidekiqのリトライに任せる
    end
  end

  private

  def handle_rate_limit(error)
    wait_seconds = error.headers["retry-after"]&.to_i || 60
    Rails.logger.warn("Rate limited. Waiting #{wait_seconds}s...")
    sleep(wait_seconds)
  end
end

# 使い方（全ジョブで include する）
class PostGenerateJob
  include Sidekiq::Job
  include JobErrorHandling
  # ...
end


# ============================================================
# AiActionCheckJob の重複実行防止
# ============================================================
# 毎15分実行されるが、前回のジョブがまだ実行中の場合に重複しないよう制御する

class AiActionCheckJob
  include Sidekiq::Job
  include JobErrorHandling
  sidekiq_options queue: :default, retry: 2

  LOCK_KEY = "lock:ai_action_check"
  LOCK_TTL = 14.minutes  # 15分より少し短く

  def perform
    # 分散ロック（Redis）
    acquired = $redis.set(LOCK_KEY, 1, nx: true, ex: LOCK_TTL.to_i)
    unless acquired
      Rails.logger.info("AiActionCheckJob: skipped (already running)")
      return
    end

    begin
      run_action_check
    ensure
      $redis.del(LOCK_KEY)
    end
  end

  private

  def run_action_check
    AiUser.where(is_active: true).find_each(batch_size: 100) do |ai|
      process_ai(ai)
    rescue => e
      Rails.logger.error("AiActionCheckJob failed for ai_id=#{ai.id}: #{e.message}")
      next  # 1体失敗しても続ける
    end
  end
end


# ============================================================
# Claude API コール共通処理
# ============================================================

module ClaudeApiCaller
  MAX_RETRIES = 2
  TIMEOUT_SECONDS = 30

  def call_claude_with_retry(prompt, max_retries: MAX_RETRIES)
    retries = 0

    begin
      client = Anthropic::Client.new(
        api_key: ENV["ANTHROPIC_API_KEY"],
        timeout: TIMEOUT_SECONDS
      )

      response = client.messages(
        model:      "claude-haiku-4-5-20251001",
        max_tokens: 1000,
        messages:   [{ role: "user", content: prompt }]
      )

      response.content.first.text

    rescue Anthropic::RateLimitError => e
      raise if retries >= max_retries
      retries += 1
      wait = e.headers["retry-after"]&.to_i || 60
      sleep(wait)
      retry

    rescue Anthropic::APIError, Net::TimeoutError, Timeout::Error => e
      raise if retries >= max_retries
      retries += 1
      sleep(2 ** retries)  # 指数バックオフ: 2秒、4秒
      retry
    end
  end
end


# ============================================================
# モニタリング・アラート設計
# ============================================================

# 監視すべき指標:
#
# 1. Sidekiqキューのバックログ
#    critical キューが100件以上 → アラート
#    （PostGenerateJobが詰まってる = AIが投稿できてない）
#
# 2. Claude APIのエラーレート
#    5分間で10件以上のAPIエラー → アラート
#
# 3. 日次の投稿生成数
#    前日比で50%以上減少 → アラート
#    （DailyStateGenerateJobが失敗してる可能性）
#
# 4. AiActionCheckJobの実行時間
#    15分を超える → アラート（次のジョブと重複する）

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Rails.logger.info("Sidekiq started")
  end

  config.death_handlers << ->(job, ex) do
    # Deadキューに入ったジョブを通知
    ErrorNotifier.notify(
      ex,
      job_class: job["class"],
      job_args:  job["args"]
    )
  end
end


# ============================================================
# 本番環境の注意事項
# ============================================================

# 1. Redis接続
#    config/cable.yml と Sidekiqで同じRedisを使う場合はDB番号を分ける
#    Sidekiq:    redis://localhost:6379/0
#    ActionCable: redis://localhost:6379/1
#    キャッシュ: redis://localhost:6379/2
#
# 2. Sidekiqのプロセス数
#    Phase 1: 1プロセス（concurrency: 10）で十分
#    AI数が1000体を超えたら2プロセスに増やすことを検討
#
# 3. AiActionCheckJobの処理時間
#    AI 100体  →  約30秒
#    AI 500体  →  約2〜3分
#    AI 1000体 →  約5分
#    15分以内に収まるかモニタリングすること
#    超えそうなら find_each の batch_size を調整するか
#    AIをシャード分割して複数ジョブに分散させる
#
# 4. Claude APIのレートリミット
#    Haiku: 1分間に50リクエスト（Tier 1）
#    AIが50体以上いる場合、15分間で750リクエスト可能
#    ただし同時に複数ジョブが走るとすぐ上限に達する
#    criticalキューのconcurrencyを4に制限しているのはこのため
#    スケールしたらTier 2以上へのアップグレードを検討
#
# 5. メモリ使用量
#    Sidekiqは1プロセスあたり200〜500MBを目安
#    find_eachで分割処理しているので大きな問題はないはず
