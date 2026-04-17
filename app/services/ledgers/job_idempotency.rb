module Ledgers
  # Phase 30c / 補強1: ジョブ側の idempotency ラッパ。
  #
  # 同じ `key` に対して `ttl` の間だけ実行を一度きりに絞る。Rails.cache（本番は SolidCache）を
  # バックエンドに使い、`unless_exist: true` で書き込みに成功した呼び出しのみ処理する。
  # 失敗しても cache key は残らないため、次のスケジュールで自然にリトライされる。
  #
  # 用途: recurring cron による Ledger Runner の重複発火を抑える。台帳側の
  # `meeting_ledgers.idempotency_key` ユニーク制約と二重防御を構成する。
  module JobIdempotency
    extend ActiveSupport::Concern
    CACHE_PREFIX = "ledgers:job".freeze
    DEFAULT_TTL = 1.day

    class_methods do
      def with_job_idempotency(key, ttl: DEFAULT_TTL)
        cache_key = "#{CACHE_PREFIX}:#{key}"
        acquired = Rails.cache.write(cache_key, Time.current.iso8601, expires_in: ttl, unless_exist: true)
        unless acquired
          Rails.logger.info("[JobIdempotency] skip duplicate key=#{key}")
          return nil
        end

        begin
          yield
        rescue StandardError
          Rails.cache.delete(cache_key)
          raise
        end
      end
    end
  end
end
