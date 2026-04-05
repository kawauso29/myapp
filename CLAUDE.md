# CLAUDE.md

Claude Code向けのプロジェクトメモ。

## Claude Codeへの指示

### コマンドの提示方法

**ユーザーはスマホからSSHでコマンドを実行することが多い。スマホでのコピペはマルチライン（複数行）が崩れやすい。**

- コマンドを提示するときは**1行のワンライナーを優先**する
- 複数のコマンドをまとめる場合は `&&` でつなぐ
- どうしても複数行になる場合は**シェルスクリプトファイルに書き出して `bash script.sh` で実行する形**を提案する
- コードブロック内のインデントや改行が崩れると実行できないため、シンプルな構造を心がける

### メモの更新ルール

- **重要な情報が出てきたら必ずこの CLAUDE.md に追記する**
- **間違いを指摘されたら、その内容と正しい情報を CLAUDE.md に記録する**

## デプロイ仕様

### 自動デプロイのトリガー

**`main` ブランチに push すると自動デプロイが走る。**

- ワークフロー: `.github/workflows/deploy.yml`
- GitHub Actions が起動し、さくらVPSにSSH接続してデプロイを実行する

### デプロイ先

| 項目 | 値 |
|------|-----|
| サーバー | さくらVPS |
| OS | Ubuntu 22.04.4 LTS |
| IP | 133.167.124.112 |
| ユーザー | ubuntu |
| アプリパス | `/home/ubuntu/myapp` |

### デプロイ手順（GitHub Actionsが自動実行）

```
git fetch origin main
git reset --hard origin/main
eval "$(rbenv init -)"
bundle install
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails runner "ActiveRecord::Tasks::DatabaseTasks.prepare_all"
RAILS_ENV=production bin/rails assets:precompile
sudo systemctl restart puma
```

### サーバー構成

- **Webサーバー**: Nginx → Puma（Unixソケット経由）
  - ソケット: `/home/ubuntu/myapp/tmp/sockets/puma.sock`
  - Puma は systemd で管理（`sudo systemctl restart puma`）
  - sudoers でパスワードなし再起動を許可済み
- **DB**: PostgreSQL（ユーザー: ubuntu、DB: myapp_production）
- **Ruby**: 3.3.7（rbenv: `~/.rbenv`）
- **Rails**: 8.1.2

### GitHub Secrets（Actions用）

| Secret名 | 内容 |
|----------|------|
| `VPS_HOST` | 133.167.124.112 |
| `VPS_USER` | ubuntu |
| `VPS_SSH_KEY` | GitHub Actions専用 ed25519 秘密鍵 |

### 502エラー時のデバッグ手順

502が出たらRailsの起動エラーを確認する（VPS上で実行）:

```bash
cd ~/myapp && RAILS_ENV=production rails runner "puts 'OK'" 2>&1 | head -5
```

- エラーが出る → Railsが起動できていない（コードのSyntaxエラー等）
- "OK" と表示される → PumaやNginxの設定問題

Pumaの再起動: `sudo systemctl restart puma`

### 過去の障害記録

#### 2026-04-05: 502エラー（Railsシンタックスエラー）

- **原因**: `admin/ai_sns_controller.rb` の `redirect_back` の書き方が間違っていた
- **誤り**: `redirect_back(fallback_location: path), notice: "..."` （noticeがカッコの外）
- **正しい**: `redirect_back fallback_location: path, notice: "..."` （noticeをカッコなしで同じ引数に）
- Ruby 3.3 では `method(args), key: val` はシンタックスエラーになる

### ローカル開発環境（Docker）

```bash
docker compose up
```

- Rails: http://localhost:3000
- DB: PostgreSQL 16（`postgres:password@localhost:5432`）
- Redis: localhost:6379
- 設定: `docker-compose.yml` + `Dockerfile.dev`
