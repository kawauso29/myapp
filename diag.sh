#!/bin/bash
echo "=== Puma Socket ==="
ls -la ~/myapp/tmp/sockets/
echo "=== Socket Active? ==="
ss -lx | grep puma || echo "NOT LISTENING"
echo "=== Curl Test ==="
curl -s --unix-socket ~/myapp/tmp/sockets/puma.sock http://localhost/up
echo ""
echo "=== Rails Boot ==="
cd ~/myapp && RAILS_ENV=production bundle exec rails runner "puts 'OK'" 2>&1 | tail -10
