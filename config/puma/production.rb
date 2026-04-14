# Puma production configuration
#
# NOTE: Puma 8.x loads ONLY config/puma/{environment}.rb when it exists,
# skipping config/puma.rb entirely. All production settings (including
# SolidQueue plugin) must be defined here.

# Load .env manually before any ENV checks.
# config/puma/production.rb is evaluated by Puma before Rails (and dotenv-rails) boots,
# so ENV vars written to .env (SOLID_QUEUE_IN_PUMA, etc.) are not available yet
# unless we load the file explicitly here.
dotenv_path = File.expand_path("../../.env", __dir__)
if File.exist?(dotenv_path)
  require "dotenv"
  Dotenv.load(dotenv_path)
end

# Worker count for cluster mode
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Thread pool
max_threads_count = 5
min_threads_count = 5
threads min_threads_count, max_threads_count

# Preload app for copy-on-write memory savings
preload_app!

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Run the Solid Queue supervisor inside of Puma for single-server deployments.
# Use async mode (threads in same process) instead of fork mode to avoid
# fork-related class loading issues that cause ActiveJob::UnknownJobClassError
# after deploys.
if ENV["SOLID_QUEUE_IN_PUMA"]
  plugin :solid_queue
  solid_queue_mode :async
end

# Listen on a unix socket for nginx reverse proxy
bind "unix:///home/ubuntu/myapp/tmp/sockets/puma.sock"

# PID file
pidfile "/home/ubuntu/myapp/tmp/pids/puma.pid"

# Logging
stdout_redirect "/home/ubuntu/myapp/log/puma.stdout.log",
                "/home/ubuntu/myapp/log/puma.stderr.log",
                true

# Allow workers to reload bundler context
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end
