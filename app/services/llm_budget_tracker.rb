# LLM API の日次呼び出し数を Redis でトラッキングし、
# 超過時はフォールバックモデルへ自動切り替えする。
#
# ENV:
#   LLM_DAILY_CALL_LIMIT   … ハードリミット（デフォルト 500 回/日）
#   LLM_SOFT_LIMIT_RATIO   … ソフトリミット比率（デフォルト 0.8 = 80%）
class LlmBudgetTracker
  KEY_PREFIX  = "llm_budget:calls"
  TTL_SECONDS = 25.hours.to_i

  # ハードリミット: 超過したら軽量モデルへフォールバック
  HARD_LIMIT  = -> { (ENV["LLM_DAILY_CALL_LIMIT"] || 500).to_i }
  # ソフトリミット: 超えたらログ警告
  SOFT_RATIO  = -> { (ENV["LLM_SOFT_LIMIT_RATIO"] || 0.8).to_f }

  # 1 回の呼び出しを記録し、現在の日次カウントを返す
  def self.increment!(provider)
    key   = redis_key(provider)
    count = redis.incr(key)
    redis.expire(key, TTL_SECONDS) if count == 1  # 初回のみ TTL 設定

    limit = HARD_LIMIT.call
    if count > limit
      Rails.logger.warn(
        "[LlmBudgetTracker] Hard limit exceeded: provider=#{provider} count=#{count}/#{limit} " \
        "— falling back to lightest model"
      )
      :over_limit
    elsif count > (limit * SOFT_RATIO.call).ceil
      Rails.logger.warn(
        "[LlmBudgetTracker] Soft limit warning: provider=#{provider} count=#{count}/#{limit}"
      )
      :near_limit
    else
      :ok
    end
  end

  def self.count(provider)
    redis.get(redis_key(provider)).to_i
  end

  def self.redis_key(provider)
    "#{KEY_PREFIX}:#{provider}:#{Date.current}"
  end

  def self.redis
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
  end
  private_class_method :redis_key, :redis
end
