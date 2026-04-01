module AiCreation
  class DraftStore
    PREFIX = "ai_draft:"
    TTL = 30.minutes.to_i

    def self.store(user_id, draft_data)
      token = SecureRandom.hex(16)
      key = "#{PREFIX}#{token}"
      data = draft_data.merge(user_id: user_id).to_json
      redis.setex(key, TTL, data)
      token
    end

    def self.fetch(token, user_id)
      key = "#{PREFIX}#{token}"
      raw = redis.get(key)
      return nil unless raw

      data = JSON.parse(raw, symbolize_names: true)
      return nil unless data[:user_id] == user_id

      data
    end

    def self.consume(token, user_id)
      data = fetch(token, user_id)
      return nil unless data

      redis.del("#{PREFIX}#{token}")
      data
    end

    def self.redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    end
  end
end
