# Picro新着チェック → LINE通知 セットアップガイド

## 1. Rails credentialsに認証情報を追加

VPS上で以下を実行:

```bash
cd /home/ubuntu/myapp && EDITOR=nano rails credentials:edit
```

以下の内容を追記:

```yaml
picro:
  login_id: yuito0924
  password: purin726

line:
  channel_secret: YOUR_LINE_CHANNEL_SECRET
  channel_token: YOUR_LINE_CHANNEL_ACCESS_TOKEN
  user_id: YOUR_OWN_LINE_USER_ID  # 自分のLINEユーザーID（後方互換）
  friend_ids:                      # 通知を送りたい友達全員のLINEユーザーIDリスト
    - Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # 友達1
    - Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # 友達2
    - Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # 友達3
```

## 2. 友達のLINE User IDの取得方法

### 重要な前提
**LINEのMessaging APIは、対象ユーザーがLINE botを「友達追加」していないとメッセージを送れません。**
友達追加してもらった後、以下の方法でUser IDを取得してください。

### User ID取得手順
1. [LINE Developers Console](https://developers.line.biz/console/) にアクセス
2. Messaging APIチャネル → 「Messaging API設定」タブ
3. Webhookを有効化し、友達にbotを追加してもらう
4. 友達がbotにメッセージを送ると、WebhookにそのユーザーのUser IDが届く
5. そのUser ID（`U`で始まる44文字）を `friend_ids` に追加

### 自分のUser IDの確認
LINE Developers Console → 「チャネル基本設定」→ 「あなたのユーザーID」

## 3. 通知の仕組み

| 設定状況 | 送信方法 | 届く範囲 |
|---------|---------|---------|
| `friend_ids` に複数ID登録 | multicast | 登録した全員 |
| `user_id` のみ | push_message | 1人だけ |
| どちらも未設定 | broadcast | botを友達追加した全員（不確実） |

**推奨**: 友達全員のUser IDを `friend_ids` に登録する。

## 4. LINE Messaging API の設定

1. https://developers.line.biz/console/ にアクセス
2. 新しいプロバイダーとチャネル（Messaging API）を作成
3. 以下を取得して credentials に設定:
   - **Channel secret**: チャネル基本設定タブ
   - **Channel access token**: Messaging API タブ → 発行

## 5. DBマイグレーション

VPS上で自動実行（GitHub Actions デプロイ時に `db:migrate` が走る）

## 6. 動作確認

```bash
cd ~/myapp && RAILS_ENV=production rails runner "PicroCheckJob.perform_now" 2>&1 | tail -20
```

ログで `送信先: N人` と表示されれば正常。`0人` の場合は `friend_ids` が未設定。

## 7. Solid Queue の起動確認

```bash
sudo systemctl restart puma
```
