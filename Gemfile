source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "jbuilder"

# Authentication (AI SNS)
gem "devise"
gem "devise-jwt"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron"
gem "redis", "~> 5.0"

# AI
gem "anthropic"
gem "ruby-openai"

# Payment
gem "stripe"

# HTTP
gem "httparty"
gem "rack-cors"
gem "rack-attack"

# Environment
gem "dotenv-rails"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

# Scraping
gem "mechanize"

# LINE Messaging API
gem "line-bot-api", "~> 1.28"

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
