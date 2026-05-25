# 07. GitHub Workflows (企画レイヤー)

## 前提

**Runner は self-hosted**。原田さんのローカルマシン上で動作する。  
→ Rails (`localhost:3000`), PG, Redis 全てローカルから直接アクセスできる。

```yaml
# 全 workflow 共通
runs-on: self-hosted
```

---

## Workflow 一覧

| Workflow | トリガ | 役割 |
|---|---|---|
| `linestamp-research.yml` | weekly cron (月曜 0:00 UTC) | 週次調査 Issue を Copilot に投げる |
| `linestamp-brand-planning.yml` | daily cron | 日次 Brand 企画 Issue × 3 |
| `linestamp-pack-planning.yml` | daily cron | 日次 Pack 企画 Issue × 10 |
| `linestamp-sync.yml` | brand_sources/ への push | Rails に sync 通知 |

---

## 1. Research (週1)

```yaml
# .github/workflows/linestamp-research.yml
name: Linestamp Research (Weekly)

on:
  schedule:
    - cron: '0 0 * * 1'   # 月曜 0:00 UTC = 月曜 9:00 JST
  workflow_dispatch:
    inputs:
      focus:
        description: "今週の調査フォーカス(空でも可)"
        required: false

jobs:
  create-research-issue:
    runs-on: self-hosted
    permissions:
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Compute ISO week
        id: week
        run: |
          WEEK=$(date -u +"%Y-W%V")
          echo "iso_week=$WEEK" >> $GITHUB_OUTPUT

      - name: Create research issue for Copilot
        uses: actions/github-script@v7
        with:
          script: |
            const week = '${{ steps.week.outputs.iso_week }}';
            const focus = '${{ inputs.focus }}' || '今週注目のLINEスタンプトレンド・季節要素・感情ニーズ';
            
            const body = `@copilot
            
            ## ミッション
            LINEスタンプ企画のための週次調査を実施し、結果を brand_sources/research/${week}/ に出力してください。
            
            ## 出力ファイル
            - brand_sources/research/${week}/findings.md (本文)
            - brand_sources/research/${week}/trends.yml (構造化キーワード)
            - brand_sources/research/${week}/brief.md (この issue 本文をそのままコピー)
            
            ## 調査フォーカス
            ${focus}
            
            ## 仕様
            docs/linestamp/PLANNING_GUIDE.md の「## 調査 (Research)」セクション参照
            
            ## 完了条件
            - [ ] findings.md に最低5つの利用シーン
            - [ ] findings.md に最低3つの感情ニーズ
            - [ ] trends.yml に keywords / seasons / emotions / age_groups 各配列
            - [ ] PR が作成され draft でレビュー待ち`;
            
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[linestamp/research] ${week} 週次調査`,
              body: body,
              labels: ['linestamp', 'research', 'auto'],
              assignees: ['Copilot']
            });
```

---

## 2. Brand Planning (日3)

```yaml
# .github/workflows/linestamp-brand-planning.yml
name: Linestamp Brand Planning (Daily)

on:
  schedule:
    - cron: '0 22 * * *'   # 22:00 UTC = 翌 7:00 JST
  workflow_dispatch:
    inputs:
      count:
        description: "今日のブランド企画数(default=3)"
        required: false
        default: "3"

jobs:
  create-brand-issues:
    runs-on: self-hosted
    permissions:
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: Find latest research
        id: research
        run: |
          LATEST=$(ls -1 brand_sources/research/ | sort | tail -1)
          echo "slug=$LATEST" >> $GITHUB_OUTPUT

      - name: Create brand planning issues
        uses: actions/github-script@v7
        with:
          script: |
            const count = parseInt('${{ inputs.count }}' || '3', 10);
            const research = '${{ steps.research.outputs.slug }}';
            const date = new Date().toISOString().slice(0,10);
            
            for (let i = 1; i <= count; i++) {
              const body = `@copilot
              
              ## ミッション
              新規LINEスタンプブランドの企画書一式を brand_sources/{新slug}/ に作成してください。
              
              ## 参考にする調査
              brand_sources/research/${research}/findings.md を必ず読むこと。
              
              ## 出力
              - brand_sources/{slug}/01_brand_theme.md
              - brand_sources/{slug}/02_base.md
              - brand_sources/{slug}/meta.yml  (series_name, character_name, research_slug)
              
              ## 仕様
              docs/linestamp/PLANNING_GUIDE.md の「## Brand 企画」を参照。
              既存ブランド brand_sources/nemuinu/ をお手本にする。
              
              ## 完了条件
              - [ ] 二段定義: 「○○ではない、○○な△△」
              - [ ] 優先順位3つを明示
              - [ ] Core/Work/Dream の表現レイヤー定義
              - [ ] NG/OK例
              - [ ] PR がレビュー待ち`;
              
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: `[linestamp/brand] ${date} #${i}`,
                body: body,
                labels: ['linestamp', 'brand-planning', 'auto'],
                assignees: ['Copilot']
              });
              
              await new Promise(r => setTimeout(r, 3000));  // 3秒空ける
            }
```

---

## 3. Pack Planning (日10)

```yaml
# .github/workflows/linestamp-pack-planning.yml
name: Linestamp Pack Planning (Daily)

on:
  schedule:
    - cron: '30 22 * * *'   # 22:30 UTC = 翌 7:30 JST
  workflow_dispatch:
    inputs:
      count:
        description: "今日のPack企画数(default=10)"
        required: false
        default: "10"

jobs:
  create-pack-issues:
    runs-on: self-hosted
    permissions:
      issues: write
    steps:
      - uses: actions/checkout@v4

      - name: List active brands
        id: brands
        run: |
          # base_ready 相当 = base_md と meta.yml が揃っている brand 一覧
          BRANDS=$(ls -1d brand_sources/*/ | xargs -n1 basename | grep -v '^_' | tr '\n' ',' | sed 's/,$//')
          echo "list=$BRANDS" >> $GITHUB_OUTPUT

      - name: Create pack planning issues
        uses: actions/github-script@v7
        with:
          script: |
            const count = parseInt('${{ inputs.count }}' || '10', 10);
            const brands = '${{ steps.brands.outputs.list }}'.split(',');
            const date = new Date().toISOString().slice(0,10);
            
            for (let i = 1; i <= count; i++) {
              const brand = brands[(i - 1) % brands.length];
              
              const body = `@copilot
              
              ## ミッション
              既存ブランド ${brand} に新しいシリーズ(Pack)を企画してください。
              出力先: brand_sources/${brand}/packs/{新pack_slug}/
              
              ## ベースブランド
              brand_sources/${brand}/01_brand_theme.md と 02_base.md を必読。
              ブランドのキャラ・世界観・トーンを尊重すること。
              
              ## 出力ファイル
              - brand_sources/${brand}/packs/{slug}/03_stamp_pack.md
              - brand_sources/${brand}/packs/{slug}/manifest.yml
              
              ## manifest.yml の構造
              \`\`\`yaml
              series_theme: "シリーズテーマ名"
              layer: "core_work" | "dream" | "weekend" | etc
              stamps:
                - number: 1
                  label: "文言"
                  situation: "シチュ説明"
                # ... 8件
              \`\`\`
              
              ## 仕様
              docs/linestamp/PLANNING_GUIDE.md の「## Pack 企画」を参照。
              
              ## 完了条件
              - [ ] 8枚すべてに label と situation
              - [ ] パック内で利用シーンに統一感
              - [ ] 既存 pack と重複しないテーマ
              - [ ] PR がレビュー待ち`;
              
              await github.rest.issues.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title: `[linestamp/pack] ${date} ${brand} #${i}`,
                body: body,
                labels: ['linestamp', 'pack-planning', 'auto'],
                assignees: ['Copilot']
              });
              
              await new Promise(r => setTimeout(r, 2000));
            }
```

---

## 4. Sync to Rails (merged 時)

```yaml
# .github/workflows/linestamp-sync.yml
name: Linestamp Sync to Rails

on:
  push:
    branches: [main]
    paths:
      - 'brand_sources/**'

jobs:
  sync:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Pull repo to Rails working dir (if separate)
        run: |
          # myapp が clone 済の前提。Rails のリポと同一なら不要
          echo "Same repo, no separate pull needed"

      - name: Trigger Rails sync via local HTTP
        env:
          SYNC_TOKEN: ${{ secrets.LINESTAMP_SYNC_TOKEN }}
        run: |
          curl -sf -X POST http://localhost:3000/webhooks/linestamp/sync \
            -H "Authorization: Bearer $SYNC_TOKEN" \
            -H "Content-Type: application/json"

      - name: Notify Slack
        if: success()
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          curl -sf -X POST $SLACK_WEBHOOK_URL \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"🔄 brand_sources synced to Rails (${{ github.sha }})\"}"
```

---

## Self-hosted runner セットアップ

リポジトリ Settings → Actions → Runners → New self-hosted runner で取得する手順を実行:

```bash
# 原田さんローカルマシンで
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.xxx.x.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.xxx.x/...
tar xzf ./actions-runner-*.tar.gz

./config.sh --url https://github.com/kawauso29/myapp --token YOUR_TOKEN
./run.sh   # フォアグラウンド起動 (またはサービス化)
```

サービス化:
```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

これで GitHub からの workflow がローカルマシン上で実行される。`localhost:3000` `localhost:7860` にアクセス可能。

---

## Secrets 設定

リポジトリ Settings → Secrets and variables → Actions:

| Secret | 用途 |
|---|---|
| `LINESTAMP_SYNC_TOKEN` | `/webhooks/linestamp/sync` の認証 |
| `SLACK_WEBHOOK_URL` | sync 完了通知用 |

---

## Issue テンプレート

```markdown
<!-- .github/ISSUE_TEMPLATE/linestamp-brand-planning.md -->
---
name: LINEスタンプ Brand 企画
about: Copilot Coding Agent に新ブランド企画を依頼
title: '[linestamp/brand] '
labels: ['linestamp', 'brand-planning']
assignees: ['Copilot']
---

@copilot

## ミッション
新規LINEスタンプブランドの企画書一式を作成してください。

## 仕様
docs/linestamp/PLANNING_GUIDE.md を参照

## 完了条件
- [ ] brand_sources/{slug}/01_brand_theme.md
- [ ] brand_sources/{slug}/02_base.md
- [ ] brand_sources/{slug}/meta.yml
- [ ] PR がレビュー待ち
```

(同様に research / pack 用も)

---

## 動作確認順序(初回)

1. self-hosted runner を起動
2. brand_sources/ を最初に整える(ねむ犬を seed として置く)
3. `workflow_dispatch` で `linestamp-research.yml` を手動実行
4. Copilot が PR を出すか確認 → マージ
5. `linestamp-sync.yml` が自動発火 → Rails が sync する
6. 管理画面で Brand/Pack/Research が見えることを確認
7. 同じく brand-planning / pack-planning を順に手動実行で確認
8. すべて OK なら cron 任せ
