# Picro新着チェック → LINE通知 セットアップガイド

## 1. Rails credentialsに認証情報を追加

VPS上で以下を実行:

```bash
cd /home/ubuntu/myapp
EDITOR=nano rails credentials:edit
```

以下の内容を追記:

```yaml
picro:
  login_id: yuito0924
  password: purin726  # ← 実際のパスワード

line:
  channel_secret: YOUR_LINE_CHANNEL_SECRET
  channel_token: YOUR_LINE_CHANNEL_ACCESS_TOKEN
  user_id: YOUR_LINE_USER_ID  # 通知先のLINEユーザーID
```

## 2. LINE Messaging API の設定

1. https://developers.line.biz/console/ にアクセス
2. 新しいプロバイダーとチャネル（Messaging API）を作成
3. 以下を取得して credentials に設定:
   - **Channel secret**: チャネル基本設定タブ
   - **Channel access token**: Messaging API タブ → 発行
   - **自分のユーザーID**: プロフィールタブ or LINE公式アカウントマネージャー

## 3. スクレイピングのHTML構造確認（要調査）

Picroのメッセージ一覧ページ（ログイン後）をブラウザで開き、
DevTools（F12）でHTMLを確認して以下を `picro_scraper_service.rb` に反映:

- ログインフォームの `action` URL
- パスワードフィールドの `name` 属性
- メッセージ一覧のCSSセレクタ（`.message-list-item` など）
- メッセージIDの取得方法

## 4. DBマイグレーション

VPS上で自動実行（GitHub Actions デプロイ時に `db:migrate` が走る）

## 5. 動作確認

```bash
# コンソールで手動実行
rails c
PicroCheckJob.perform_now

# ログ確認
tail -f log/production.log
```

## 6. Solid Queue の起動確認

Rails 8.1 + Solid Queue は Puma と同じプロセス内で動くため、
Pumaを再起動すれば自動的にジョブワーカーも起動します。

```bash
sudo systemctl restart puma
```
