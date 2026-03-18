#!/bin/bash
set -e

# ============================================================
# Claude Terminal セットアップスクリプト
# 使い方: bash script/setup_claude_terminal.sh
# ============================================================

PUMA_SOCK="/home/ubuntu/myapp/tmp/sockets/puma.sock"
NGINX_CONF="/etc/nginx/sites-available/myapp"
PUMA_OVERRIDE_DIR="/etc/systemd/system/puma.service.d"

# --- 入力 ---
echo ""
echo "=== Claude Terminal セットアップ ==="
echo ""
read -p "ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY
read -p "ログインユーザー名 (デフォルト: admin): " CLAUDE_USER
CLAUDE_USER=${CLAUDE_USER:-admin}
read -s -p "ログインパスワード: " CLAUDE_PASS
echo ""
echo ""

# --- Claude CLI インストール ---
echo "[1/4] Claude CLI のインストール..."
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
sudo npm install -g @anthropic-ai/claude-code
CLAUDE_BIN=$(which claude)
echo "  → Claude: $CLAUDE_BIN"

# --- 環境変数を systemd override に追加 ---
echo "[2/4] Puma の環境変数を設定..."
sudo mkdir -p "$PUMA_OVERRIDE_DIR"
sudo tee "$PUMA_OVERRIDE_DIR/claude_env.conf" > /dev/null << ENVEOF
[Service]
Environment="ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}"
Environment="CLAUDE_TERMINAL_USER=${CLAUDE_USER}"
Environment="CLAUDE_TERMINAL_PASSWORD=${CLAUDE_PASS}"
Environment="CLAUDE_WORKING_DIR=/home/ubuntu/myapp"
Environment="CLAUDE_BIN=${CLAUDE_BIN}"
ENVEOF
sudo systemctl daemon-reload
echo "  → 設定完了"

# --- Nginx 設定更新 ---
echo "[3/4] Nginx の設定を更新..."
sudo tee "$NGINX_CONF" > /dev/null << 'NGINXEOF'
upstream myapp { server unix:///home/ubuntu/myapp/tmp/sockets/puma.sock; }

server {
    listen 80;
    server_name 133.167.124.112;
    root /home/ubuntu/myapp/public;

    location /cable {
        proxy_pass http://myapp;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location / {
        try_files $uri @myapp;
    }

    location @myapp {
        proxy_pass http://myapp;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF
sudo nginx -t && sudo nginx -s reload
echo "  → Nginx リロード完了"

# --- Puma 再起動 ---
echo "[4/4] Puma を再起動..."
sudo systemctl restart puma
sleep 3
sudo systemctl is-active puma && echo "  → Puma 起動確認 OK" || echo "  → Puma 起動失敗 (sudo journalctl -u puma で確認)"

echo ""
echo "=== セットアップ完了 ==="
echo "  アクセス: http://133.167.124.112/claude"
echo "  ユーザー名: ${CLAUDE_USER}"
echo "  ※ Claudeのコードを先にgit pushしてからアクセスしてください"
