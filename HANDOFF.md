# myapp プロジェクト引き継ぎメモ（Claude Code向け）

## プロジェクト概要

個人用ライフスタイル管理プラットフォーム。株式売買、水耕栽培など様々なプライベート機能を統合するRailsモノリスアプリ。

---

## 完了済みの作業（Phase 1〜3）

### Phase 1: さくらVPSにRails本番環境を構築 ✅

1. さくらVPS契約（2GBプラン、Ubuntu 22.04）
2. SSH接続確認（ユーザー: ubuntu、IP: 133.167.124.112）
3. swap 2GB追加（`/swapfile`）
4. Ruby 3.3.7インストール（rbenv）
5. Rails 8.1.2インストール（`gem install rails`）
6. PostgreSQLインストール（DBユーザー: ubuntu）
7. Nginxインストール・設定
   - `/etc/nginx/sites-available/myapp` にupstream + server設定
   - Unixソケット経由でPumaに接続
   - シンボリックリンクで有効化、default設定は削除
8. Node.js 22.x + Yarnインストール
9. `rails new myapp -d postgresql` でアプリ作成（パス: `/home/ubuntu/myapp`）
10. database.yml修正（username: myapp → ubuntu）
11. production DB作成（`rails db:create`）
12. アセットプリコンパイル
13. Puma設定にUnixソケットバインド追加
    ```ruby
    bind "unix:///home/ubuntu/myapp/tmp/sockets/puma.sock"
    ```
14. Pumaをsystemdでサービス化（`/etc/systemd/system/puma.service`）
    - SECRET_KEY_BASEはサービスファイル内のEnvironmentに直接記載
    - `sudo systemctl enable puma` で自動起動設定済み
    - `sudo systemctl restart puma` でパスワードなし再起動可能（sudoers設定済み）
15. パーミッション修正
    - `/home/ubuntu` を `chmod 755`（Nginx www-dataユーザーがアクセスするため）
    - `puma.sock` を `chmod 777`
16. さくらVPSパケットフィルタでTCP 80, 443を許可
17. `HomeController#index` を作成、`root "home#index"` 設定
18. http://133.167.124.112 でRailsのHome#indexが表示されることを確認

### Phase 2: GitHub連携 ✅

1. VPS上でGit初期設定（user.name: k.harada, email: may29kh@gmail.com）
2. GitHubにPrivateリポジトリ作成: https://github.com/kawauso29/myapp
3. VPS上でSSHキー作成 → GitHubに公開鍵登録（Title: sakura-vps）
4. `ssh -T git@github.com` で接続確認OK
5. Initial commit → `git push -u origin main`

### Phase 3: GitHub Actionsで自動デプロイ ✅

1. `.github/workflows/deploy.yml` を作成
   - mainブランチへのpushでトリガー
   - `appleboy/ssh-action@v1` でVPSにSSH接続
   - 実行内容: git pull → bundle install → db:migrate → assets:precompile → restart puma
2. GitHub Secrets設定
   - `VPS_HOST`: 133.167.124.112
   - `VPS_USER`: ubuntu
   - `VPS_SSH_KEY`: GitHub Actions専用ed25519秘密鍵（VPSで生成、authorized_keysに公開鍵追加済み）
3. sudoers設定: `ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl restart puma`
4. デプロイテスト成功（GitHub Actions緑チェック確認）

**現在の自動デプロイフロー:**
```
ローカル or Codespace で git push
  → GitHub Actions起動
    → SSH でさくらVPSに接続
      → git pull, bundle install, db:migrate, assets:precompile
      → sudo systemctl restart puma
  → http://133.167.124.112 に反映
```

---

## これからやるタスク

### Phase 4: ローカルDocker開発環境 ✅

- `Dockerfile.dev`（Ruby 3.3.7ベース）
- `docker-compose.yml`（Rails + PostgreSQL）
- `docker compose up` で開発サーバー起動確認済み

### Phase 5: AI開発ツール導入 ⬜（未着手）

GitHub CodespaceにClaude Codeを導入予定。
Codespace上で開発 → git push → 自動デプロイの流れ。

### 機能開発1: Picro新着チェック → LINE通知 🔄（実装済み・設定待ち）

**概要**: https://picro.jp のログイン先にメッセージが届く。毎日新着を確認し、あればLINEに通知する。

**Picroについて**:
- メールアドレス+パスワードでログイン
- ログインURL、フォーム構造は未調査（最初にやるべき）

**設計**:
```
[さくらVPS: myapp]
  ├ 定期ジョブ（毎日 or 数時間おき）
  │   ├ Picroにログイン（HTTP POST）
  │   ├ メッセージ一覧ページをスクレイピング
  │   ├ 前回チェック時と比較して新着を検出
  │   └ 新着あり → LINE Messaging APIで通知
  │
  ├ DBテーブル
  │   ├ picro_credentials（ログイン情報の暗号化保存）
  │   └ picro_messages（既読管理、重複通知防止）
  │
  └ LINE Bot設定
      └ Messaging API（チャネルアクセストークン）
```

**必要なgem**:
- `mechanize` or `faraday` + `nokogiri`（スクレイピング）
- `line-bot-api`（LINE Messaging API）

**LINE通知**:
- LINE Developersアカウント登録済み
- LINE Notifyは2025年3月終了のため使用不可
- LINE Messaging API（公式アカウント）を使用
- 無料枠: 月200通（個人用途なら十分）
- LINE公式アカウント作成 → チャネルアクセストークン取得はまだ

**実装手順**:
1. Picroのログインフォームの構造を調査（URL、フォームパラメータ、CSRF）
2. スクレイピングでログイン→メッセージ取得するサービスクラス作成
3. LINE公式アカウント作成 → チャネルアクセストークン取得
4. LINE通知サービスクラス作成
5. 定期ジョブ設定（Solid Queue or whenever gem）
6. credentials管理（Rails encrypted credentials）

### 将来の機能候補 ⬜

- 株式売買関連（詳細未定）
- 水耕栽培管理（スマート農業への関心あり）

---

## 環境詳細

### さくらVPS

- **OS**: Ubuntu 22.04.4 LTS
- **メモリ**: 2GB + 2GB swap
- **IP**: 133.167.124.112
- **ユーザー**: ubuntu
- **Ruby**: 3.3.7（rbenv: ~/.rbenv）
- **Rails**: 8.1.2
- **DB**: PostgreSQL（ユーザー: ubuntu、DB: myapp_production）
- **Webサーバー**: Nginx → Puma（Unixソケット）
- **Puma**: systemdで管理（`sudo systemctl restart puma`）
- **アプリパス**: `/home/ubuntu/myapp`
- **ソケット**: `/home/ubuntu/myapp/tmp/sockets/puma.sock`
- **Node.js**: 22.x（NodeSourceからインストール済み）
- **Yarn**: インストール済み
- **OpenClaw**: インストール済みだが未使用（`openclaw`コマンドは使える）
- **パケットフィルタ**: SSH(22), HTTP(80), HTTPS(443) 許可

### GitHub

- **リポジトリ**: https://github.com/kawauso29/myapp (Private)
- **ユーザー名**: kawauso29
- **メール**: may29kh@gmail.com

### ローカルPC

- **OS**: Windows
- **Docker Desktop**: インストール済み
- **SSHキー**: `C:\Users\k.harada\.ssh\id_ed25519`（GitHubに登録済み）

---

## 注意事項・既知の問題

- `.bashrc` の SECRET_KEY_BASE に余計な `KEY=` プレフィックスがついている（systemdサービス側に正しい値があるので実害なし）
- Puma 7では `-d`（デーモン化）オプションが廃止されている。systemdで管理すること。
- Nginx設定ファイルは改行なしの一行で書かれているが動作に問題なし。

---

## 開発者について

- Railsエンジニア（DtoC メーカー勤務）
- SEOインフラ、サービスアーキテクチャ、内部ツール設計が得意
- Docker開発環境での経験あり
- 応用情報技術者試験の学習中
- 手を動かして自分で学ぶスタイルを好む
- 結論を先に、端的な説明を好む
- わからないことは都度質問するタイプ
