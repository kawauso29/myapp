#!/bin/bash
set -e

echo "=== AI SNS Production Setup ==="

bundle install --without development test

RAILS_ENV=production bundle exec rails db:migrate
RAILS_ENV=production bundle exec rails db:seed

echo "=== Setup complete ==="
