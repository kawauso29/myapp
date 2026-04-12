# GitHub Copilot Instructions

このリポジトリは Ruby on Rails 8.1 + Expo (React Native Web) のフルスタックアプリです。
以下のルールを必ず守ってコードを生成・修正してください。

## プロジェクト概要

- **バックエンド**: Ruby 3.3.7 / Rails 8.1.2
- **フロントエンド**: Expo (React Native Web) / TypeScript
- **DB**: PostgreSQL（本番: myapp_production）
- **キャッシュ/キュー**: Redis + Solid Queue
- **本番サーバー**: さくらVPS（Ubuntu 22.04 / Nginx + Puma）

## ドキュメント連動更新ルール

- `.github/copilot-instructions.md` と `CLAUDE.md` は連動ドキュメントとして扱う
- 運用ルールを更新したら、**必ず両方を同時に更新**する
- 片方だけ更新した場合は、同じ変更をもう片方にも反映して整合性を保つ

## コーディングルール（Ruby / Rails）

### やってはいけないこと（CIで必ず引っかかる）

- `Time.now` は使わない → **`Time.current`** を使う（Rails/TimeZone cop）
- `"str" + method()` の文字列結合は使わない → **`"str#{method()}"`** 補間を使う
- `head :unauthorized and return` は使わない → **`return head :unauthorized`** を使う
- private ブロック内に定数を定義しない → **private より前に定義する**
- `actions/checkout@v6` は存在しない → **`@v4`** を使う

### メソッド・スタイル

- `redirect_back` の引数はカッコなし: `redirect_back fallback_location: path, notice: "..."` （Ruby 3.3でカッコ＋カンマはSyntaxError）
- Rails の規約に従い、controller は `before_action` でフィルタを定義する

## デプロイ・CI のルール

### ブランチ戦略

1. 作業は必ずフィーチャーブランチ（`claude/...` または `copilot/...`）で行う
2. 作業前に `git branch -a` で重複ブランチがないか確認する
3. CI（scan_ruby / scan_js / lint / test / system-test）が全て通ってからマージする
4. マージ後はブランチを削除する（ローカル・リモート両方）

### CI/CD の仕組み

```
main への直接 push
    ↓
[CI ワークフロー] scan_ruby / scan_js / lint / test / system-test
    ↓ 全成功                       ↓ 失敗
[Deploy ワークフロー]           [Auto Fix ワークフロー]
  ↓ ヘルスチェック（3回）          ↓ rubocop --autocorrect
  ↓ 失敗 → 自動ロールバック        ↓ 自動修正PR作成 + Slack通知
  ↓ Slack通知

PR の自動マージ（auto_merge.yml）
    ↓
[auto_merge] CI pass → PR マージ → deploy.yml を workflow_dispatch
    ↓
[Deploy ワークフロー]（上記と同じ）
```

- **デプロイは CI 成功後のみ**: `deploy.yml` は `workflow_run` で `main` の CI 完了（success）を待つ
- **手動デプロイ**: `workflow_dispatch` でいつでも実行可能
- **auto_merge はマージ成功後に deploy を直接 dispatch する**: GITHUB_TOKEN によるマージでは push イベントが発火せず CI→deploy の連鎖が起きないため、`workflow_dispatch` で deploy.yml を直接起動する
- **自動処理が止まった理由を通知する**: 自動PR/自動マージは CI 失敗時にスキップ理由を通知し、main CI 失敗時は「デプロイ未実行」の理由を通知する

### デプロイ先

| 項目 | 値 |
|------|-----|
| サーバー | さくらVPS |
| IP | 133.167.124.112 |
| アプリパス | `/home/ubuntu/myapp` |
| Ruby | 3.3.7（rbenv） |

### 502エラー時のデバッグ

```bash
cd ~/myapp && RAILS_ENV=production rails runner "puts 'OK'" 2>&1 | head -5
```

- エラー → Railsシンタックスエラー等（コードを確認）
- "OK" → Puma/Nginx設定問題

## GitHub Actions ワークフロー修正時のルール

- `uses: actions/checkout` は必ず **`@v4`** を使う（v6は存在しない）
- ジョブには `permissions: contents: read` を最小権限で明示する
- Slack通知の JSON ペイロードは必ず **`jq`** で生成する（コミットメッセージの特殊文字でJSONが壊れるため）
- ロールバック用の一時ファイルは `/tmp/pre_deploy_sha_<run_id>` のように run_id で一意にする
- `auto_merge.yml` の保護対象では `.github/workflows/` 全体を一律除外しない。運用系（`auto_merge.yml` / `deploy.yml` / `auto_create_pr.yml` / `create_pr.yml` / `post_deploy_cleanup.yml`）は自動マージ対象に含める
- `ActiveJob::UnknownJobClassError` 再発防止のため、定期実行ジョブを追加・改名したら `config/initializers/required_job_classes.rb` と `lib/tasks/solid_queue.rake` の `REQUIRED_JOB_CLASSES` に同時反映する

## Slack 通知

- Webhook URL: `${{ secrets.SLACK_WEBHOOK_URL }}`
- JSON は必ず `jq -n --arg key value '...'` で生成する（インジェクション・改行対策）

## ローカル開発

```bash
docker compose up
```

- Rails: http://localhost:3000
- DB: PostgreSQL 16（`postgres:password@localhost:5432`）
- Redis: localhost:6379

## DBスナップショット（本番DB情報のJSON同期）

本番DBのデータをJSON形式でエクスポートし、`db-snapshots` ブランチに保存する仕組みがあります。

### 構成

| ファイル | 役割 |
|---|---|
| `lib/tasks/db_snapshot.rake` | `bin/rails db:snapshot` タスク（JSONをstdoutへ出力） |
| `.github/workflows/db_snapshot.yml` | VPS上でタスクを実行し `db-snapshots` ブランチへコミット |

### 実行方法

- **管理画面**: Admin Dashboard ナビの「DBスナップショット取得」ボタン
  - `DEPLOY_TOKEN` 環境変数（GitHub PAT / workflow権限）が必要
- **GitHub Actions UI**: Actions → "DB Snapshot for Claude" → Run workflow

### スナップショットの内容

- 全テーブルのレコード件数
- センシティブカラムを除いた各モデルの直近データ（users, ai_users, ai_profiles, ai_posts 等）
- 除外カラム: `encrypted_password`, `reset_password_token`, `stripe_customer_id`, `stripe_subscription_id`

### 注意

- 出力先ブランチは `db-snapshots`（orphanブランチ）
- ファイル名は `db_snapshot.json`（毎回上書き）
- 実行のたびに `snapshot: YYYY-MM-DD HH:MM UTC` でコミットされる

## PR作成時のチェックリスト

1. `bin/rubocop` でエラーがないことを確認
2. `bundle exec rspec` でテストが通ることを確認
3. CI失敗を修正した場合は `CLAUDE.md` の「CIエラーの原因になったこと」に追記する

## PR作成基準

### PR作成前の確認手順（必須）

**この順序でチェックしてから PR を作成する:**

1. **変更の性質を確認する**
   - ドキュメント・コメントのみの変更か、アプリ挙動に影響するか判断する
2. **ローカル検証を完了する**
   - `bin/rubocop` でLintエラーがないことを確認
   - `bundle exec rspec` でテストが通ることを確認
   - フロント変更がある場合はフロント側テストも実行
3. **以下の条件を全て満たしたら PR を作成する**
   - 変更目的が明確である
   - 失敗テストがない
   - セキュリティ・機密情報が混入していない
   - 差分がレビュー可能なサイズである

### PR作成の判断ルール

| 変更の種類 | PR作成のタイミング |
|---|---|
| 軽微変更（文言・コメントのみ） | まとめて1つのPR可 |
| 挙動変更あり | 毎回PR作成 |
| CI不安要素あり | 手動確認完了後にPR作成 |
