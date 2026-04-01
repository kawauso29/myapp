# Puma production configuration
# This file is loaded in addition to config/puma.rb when
# RAILS_ENV=production (via `require_relative` or `-C` flag).

# Worker count for cluster mode
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Thread pool
max_threads_count = 5
min_threads_count = 5
threads min_threads_count, max_threads_count

# Preload app for copy-on-write memory savings
preload_app!

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
