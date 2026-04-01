class Rack::Attack
  # Redisキャッシュを使用（なければメモリ）
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))

  # 認証エンドポイントのレート制限（IP単位: 5req/20sec）
  throttle("auth/sign_in", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
  end

  throttle("auth/sign_up", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/auth/sign_up" && req.post?
  end

  # APIエンドポイント全体（IP単位: 300req/5min）
  throttle("api/general", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # ブロック時のレスポンス
  self.throttled_responder = lambda do |req|
    [429, { "Content-Type" => "application/json" }, [{ error: "Too many requests. Please try again later." }.to_json]]
  end
end
