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
gem "line-bot-api", "~> 2.9"

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
