#!/usr/bin/env bash
# =============================================================================
# A案: LLM実行系一式 + anthropic + ruby-openai + redis を撤去するワンショット。
#   - リポジトリのルートで実行する: bash cleanup_a.sh
#   - 死んでいた LLM 経路(LlmClient / Llm::Gateway / LlmCaller / LlmBudgetTracker)を削除
#   - Redis 依存を撤去(rack_attack→MemoryStore / ActionCable→async)
#   - 未使用 gem も同時に削除(sidekiq / sidekiq-cron / httparty / kaminari / image_processing)
#   - Linestamp / Picro のコア機能には影響なし
# 透過撤去(ChromaKeyProcessor) と (A)brand_ideas / (C)identity_axes は別作業として保留。
# =============================================================================
set -euo pipefail

# --- リポジトリルートか確認 ---
if [ ! -f Gemfile ] || [ ! -f config/application.rb ]; then
  echo "ERROR: リポジトリのルートで実行してください (Gemfile が見つかりません)" >&2
  exit 1
fi

echo "==> 1/6 死んでいる LLM 実行系と Redis initializer を削除"
rm -f \
  app/services/llm_client.rb \
  app/services/llm_budget_tracker.rb \
  app/services/llm/gateway.rb \
  app/jobs/concerns/llm_caller.rb \
  spec/services/llm/gateway_spec.rb \
  config/initializers/redis.rb \
  config/initializers/sidekiq.rb
rmdir --ignore-fail-on-non-empty app/services/llm spec/services/llm 2>/dev/null || true

echo "==> 2/6 Gemfile を書き換え (anthropic/ruby-openai/redis/sidekiq系/httparty/kaminari/image_processing を除去)"
cat > Gemfile <<'RUBY'
source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "jbuilder"

# Authentication
gem "devise"
gem "devise-jwt"

# Background jobs / Cache / Cable (Solid Stack)
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# HTTP
gem "rack-cors"
gem "rack-attack"

# Environment
gem "dotenv-rails"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

# State machine
gem "aasm"

# Image processing
gem "mini_magick"

# Slack API
gem "slack-ruby-client"

# ZIP
gem "rubyzip", require: "zip"

# Scraping
gem "mechanize"

# LINE Messaging API
gem "line-bot-api", "~> 2.8"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "bullet"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 6.0"
end
RUBY

echo "==> 3/6 ActionCable を redis から async に切り替え (channel が1つも無いので async で十分)"
cat > config/cable.yml <<'YAML'
development:
  adapter: async

test:
  adapter: test

production:
  adapter: async
YAML

echo "==> 4/6 rack_attack を MemoryStore に切り替え (Redis 依存を撤去)"
cat > config/initializers/rack_attack.rb <<'RUBY'
class Rack::Attack
  if Rails.env.test?
    Rack::Attack.enabled = false
  else
    # メモリキャッシュでレート制限(Redis 依存を撤去 / シングルプロセス Puma 前提)
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    # 認証エンドポイントのレート制限(IP単位: 5req/20sec)
    throttle("auth/sign_in", limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
    end

    throttle("auth/sign_up", limit: 5, period: 20.seconds) do |req|
      req.ip if req.path == "/api/v1/auth/sign_up" && req.post?
    end

    # APIエンドポイント全体(IP単位: 300req/5min)
    throttle("api/general", limit: 300, period: 5.minutes) do |req|
      req.ip if req.path.start_with?("/api/")
    end

    # ブロック時のレスポンス
    self.throttled_responder = lambda do |req|
      [ 429, { "Content-Type" => "application/json" }, [ { error: "Too many requests. Please try again later." }.to_json ] ]
    end
  end
end
RUBY

echo "==> 5/6 routes.rb の Sidekiq Web マウントを除去 / docker-compose の redis を除去"
perl -0pi -e 's/\n  # Sidekiq Web UI.*?\n  end\n//s' config/routes.rb

cat > docker-compose.yml <<'YAML'
version: "3.8"

services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: rails server -b 0.0.0.0
    volumes:
      - .:/myapp
    ports:
      - "3000:3000"
    depends_on:
      - db
    environment:
      DATABASE_URL: postgres://postgres:password@db:5432/myapp_development

volumes:
  pgdata:
YAML

# CLAUDE.md に変更記録を追記(非破壊)
cat >> CLAUDE.md <<'MD'

## 変更記録: A案クリーンアップ (LLM実行系 + Redis 撤去)

- 死んでいた LLM 経路を削除: `LlmClient` / `Llm::Gateway` / `LlmCaller` / `LlmBudgetTracker`(剪定済み AI SNS の残骸。どこからも呼ばれていなかった)
- gem 削除: `anthropic` `ruby-openai` `redis` `sidekiq` `sidekiq-cron` `httparty` `kaminari` `image_processing`
- Redis 撤去に伴う切替: `rack_attack` → MemoryStore / ActionCable(`cable.yml`) → async(channel 不在のため)
- `config/initializers/{redis,sidekiq}.rb` と routes.rb の Sidekiq::Web マウントを削除
- プロンプトは `PromptComposer` の文字列合成のみで生成され LLM 不使用。画像生成は Designer 手動。よってコア機能(Linestamp / Picro)に影響なし
MD

echo "==> 6/6 残存参照チェック + bundle install"
echo "-- 残存参照(0件であるべき):"
grep -rn --include='*.rb' -E 'LlmClient|Llm::Gateway|LlmCaller|LlmBudgetTracker|\$redis|Redis\.new|RedisCacheStore|Sidekiq' app config lib spec 2>/dev/null || echo "  (なし)"

set +e
echo "-- bundle install (ネットワークが無い場合はスキップして後で実行してください):"
bundle install
BUNDLE_RC=$?
set -e

echo
echo "============================================================"
echo " A案クリーンアップ完了。"
echo "  次の確認を推奨:"
echo "    bin/rubocop"
echo "    bundle exec rspec"
echo "    git diff --stat"
if [ "${BUNDLE_RC:-1}" -ne 0 ]; then
  echo "  ※ bundle install が未完了です。ネットワークのある環境で再実行してください。"
fi
echo "============================================================"
