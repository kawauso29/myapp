# Self-hosted Runner セットアップガイド（さくらVPS）

`deploy.yml` と `db_snapshot.yml` は `[self-hosted, sakura-vps]` ラベルの runner で動作します。  
以下の手順でさくらVPS（ubuntu ユーザー）にインストールしてください。

## 1. GitHub から runner をダウンロード

GitHub リポジトリの Settings → Actions → Runners → "New self-hosted runner" から  
最新の runner URL とトークンを取得して実行します。

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# GitHub UI に表示されるコマンドをそのまま実行（URL・トークンは毎回異なる）
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/vX.X.X/actions-runner-linux-x64-X.X.X.tar.gz
tar xzf actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/kawauso29/myapp --token <TOKEN_FROM_GITHUB_UI> --labels sakura-vps --unattended
```

> ラベルは `sakura-vps` を必ず指定すること（ワークフローの `runs-on: [self-hosted, sakura-vps]` と対応）。

## 2. systemd サービスとして登録

```bash
sudo ./svc.sh install ubuntu
sudo ./svc.sh start
sudo systemctl enable actions.runner.kawauso29-myapp.ubuntu
```

確認:

```bash
sudo systemctl status actions.runner.kawauso29-myapp.ubuntu
```

## 3. sudo 権限の確認

デプロイスクリプトは以下のコマンドを `sudo` で実行します。  
`/etc/sudoers.d/ubuntu` に以下が設定済みであること:

```
ubuntu ALL=(ALL) NOPASSWD: /bin/systemctl restart puma, /bin/systemctl stop puma, /bin/systemctl reload nginx, /bin/cp, /usr/sbin/nginx
```

## 4. 必要ツールの確認

```bash
which jq curl git rbenv
```

- `jq` が未インストールの場合: `sudo apt-get install -y jq`

## 5. rbenv の確認

runner はシェルプロファイルを読み込まないため、ワークフロー内で明示的に PATH を設定しています。  
以下が通ることを確認:

```bash
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
ruby --version  # → ruby 3.3.7
```

## トラブルシューティング

### runner が offline になる場合

```bash
sudo systemctl restart actions.runner.kawauso29-myapp.ubuntu
```

### runner のアップデート

新しいバージョンが利用可能な場合、ジョブ実行時に自動アップデートが走ります。  
手動で実行する場合:

```bash
cd ~/actions-runner
sudo ./svc.sh stop
./config.sh remove --token <TOKEN>
# 最新バージョンを再ダウンロード・設定
sudo ./svc.sh install ubuntu && sudo ./svc.sh start
```

### ワークスペースのクリーンアップ

runner のワークスペース（`~/actions-runner/_work/`）が肥大化した場合:

```bash
rm -rf ~/actions-runner/_work/myapp/myapp/
```

次回実行時に自動で再チェックアウトされます。
