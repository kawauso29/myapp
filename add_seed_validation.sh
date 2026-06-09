#!/usr/bin/env bash
#
# add_seed_validation.sh
# ------------------------------------------------------------------
# 「seed ファイルを作っても本番 apply まで検証されない」問題を解決する。
#
# === 根本原因（調査結果）===
#   seed ファイル自体は作れる。問題は検証ポイントが本番までどこにもないこと:
#     1. ARTS213 に ruby が無い → ローカルで slug を確認できない
#     2. CI(rspec)は pending の実 seed を eval しない
#        spec/tasks/linestamp_apply_imports_spec.rb の
#        mark_existing_pending_imports_as_applied が、実在 pending を eval 前に
#        SeedApplication=applied にしてしまう。→ slug を間違えても CI はグリーン
#     3. 検証は本番 VPS の linestamp-apply-imports.yml で初めて走り、
#        ArgumentError(Unknown ... slug)で SeedApplication=failed、
#        ファイルは pending/ に取り残される(= PR 保留の正体)
#
# === この修正がやること ===
#   (1) rake linestamp:validate_imports を新設
#       - masters を seed して slug を解決可能にする
#         (masters.rb は test 環境では自動実行されないため明示 call が必須)
#       - research_slug は本番 apply 済みデータ依存なので「検証用スタブ」を
#         自動生成し、upsert_brand! の存在チェックを通してその先の
#         theme / attribute / stamp 構造まで実際に検証する
#       - 各 seed を必ず ROLLBACK するトランザクション内で eval(本番非破壊)
#       - unknown slug / 構造エラーがあれば exit 1(マージ前に赤くする)
#       - 失敗時は CI ログに「利用可能な master slug 一覧」を出力
#   (2) CI に seed-check ジョブを追加し notify / dispatch_deploy の needs に組込
#       → PR / push の段階で seed の不正をブロック(本番 apply 前に気づける)
#   (3) docs/linestamp/MASTER_SLUGS.md を生成(ruby 無しで読める slug 辞書)
#
# 変更ファイル:
#   lib/tasks/linestamp_validate_imports.rake   (新規)
#   .github/workflows/ci.yml                    (seed-check ジョブ追加)
#   docs/linestamp/MASTER_SLUGS.md              (新規・静的)
#
# ARTS213 には ruby が無いので ruby / rails / rspec は一切叩かない。
# すべて冪等。再実行しても二重追加しない(存在ガード)。
# ------------------------------------------------------------------
set -euo pipefail

cd ~/source/myapp

echo "==> main を origin に同期"
git fetch origin main
git checkout main
git reset --hard origin/main

echo "==> rake linestamp:validate_imports を作成(冪等)"
RAKE=lib/tasks/linestamp_validate_imports.rake
if [ -f "$RAKE" ]; then
  echo "rake: 既に存在 — スキップ"
else
  cat > "$RAKE" <<'RUBY'
# frozen_string_literal: true

# linestamp:validate_imports
# ------------------------------------------------------------------
# pending/*.rb の seed ファイルを「本番に触れず」検証する CI 用タスク。
#
# CI(rspec)は apply_imports spec が実 pending を eval 前に applied 扱いに
# するため、slug ミスや構造エラーがグリーンのまま本番 apply で初めて落ちる。
# このタスクは pending を実際に eval してマージ前に検出する。
#
#   - masters を seed(test 環境では masters.rb 末尾が自動 call しないため明示)
#   - research_slug は本番 apply 済みデータ依存 → 検証用スタブを自動生成し、
#     upsert_brand! の存在チェックを通してその先(theme/attribute/stamp)まで検証
#   - 各ファイルを必ず ROLLBACK するトランザクション内で eval(非破壊)
#   - 失敗があれば利用可能 slug 一覧を出して exit 1
# ------------------------------------------------------------------
namespace :linestamp do
  desc "Validate pending seed import files without persisting (CI pre-merge gate)"
  task validate_imports: :environment do
    pending_dir = Rails.root.join("db/seeds/linestamp/imports/pending")
    files = Dir.glob(pending_dir.join("*.rb"))
               .reject { |p| File.basename(p).start_with?("test_") }
               .sort

    if files.empty?
      puts "[validate_imports] 検証対象の pending seed はありません。"
      next
    end

    # slug 解決に master が必須。masters.rb は Rails.env.test? では自動実行
    # されない(ファイル末尾ガード)ため、ここで明示的に seed する。
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call

    failures = []

    files.each do |path|
      name = File.basename(path)
      src  = File.read(path)
      begin
        ActiveRecord::Base.transaction do
          # research lineage は本番 apply 済みデータに依存するため、参照されて
          # いる research_slug の検証用スタブを用意して存在チェックを通す。
          # (research の有無自体は本番状態の問題で CI では判定不能)
          src.scan(/research_slug:\s*["']([^"']+)["']/).flatten.uniq.each do |slug|
            Linestamp::Research.find_or_create_by!(slug: slug) do |r|
              r.title = "[validate stub] #{slug}"
            end
          end

          eval(src, TOPLEVEL_BINDING, path) # rubocop:disable Security/Eval
          raise ActiveRecord::Rollback # 検証のみ。本番非破壊。
        end
        puts "  ✓ #{name}"
      rescue StandardError => e
        failures << { file: name, error: "#{e.class}: #{e.message}" }
        puts "  ✗ #{name}  ->  #{e.class}: #{e.message}"
      end
    end

    if failures.any?
      puts ""
      puts "========================================"
      puts "[validate_imports] #{failures.size} 件の seed が検証に失敗しました。"
      failures.each { |f| puts "  - #{f[:file]}: #{f[:error]}" }
      puts ""
      puts "--- 利用可能な master slug(この中から選ぶこと)---"
      puts "communication_themes: #{Linestamp::CommunicationTheme.order(:position).pluck(:slug).join(' ')}"
      Linestamp::AttributeAxis.order(:position).each do |ax|
        slugs = Linestamp::AttributeValue.where(axis: ax).order(:position).pluck(:slug)
        puts "#{ax.slug}: #{slugs.join(' ')}"
      end
      puts "========================================"
      abort("[validate_imports] FAILED")
    end

    puts ""
    puts "[validate_imports] 全 #{files.size} 件 OK。"
  end
end
RUBY
  echo "rake: 作成 $RAKE"
fi

echo "==> ci.yml に seed-check ジョブを追加 + needs に組込(冪等)"
python3 - <<'PY'
p = ".github/workflows/ci.yml"
s = open(p, encoding="utf-8").read()

if "seed-check:" in s:
    print("ci: seed-check 既存 — スキップ")
else:
    job = (
        "  seed-check:\n"
        "    runs-on: [self-hosted, sakura-vps]\n"
        "\n"
        "    steps:\n"
        "      - name: Checkout code\n"
        "        uses: actions/checkout@v4\n"
        "\n"
        "      - name: Setup Ruby via rbenv\n"
        "        run: |\n"
        '          echo "$HOME/.rbenv/bin" >> "$GITHUB_PATH"\n'
        '          echo "$HOME/.rbenv/shims" >> "$GITHUB_PATH"\n'
        "\n"
        "      - name: Install gems\n"
        "        run: bundle install --jobs 2 --retry 3\n"
        "\n"
        "      - name: Validate pending seed import files\n"
        "        env:\n"
        "          RAILS_ENV: test\n"
        "          DATABASE_URL: postgres://postgres:password@localhost:5432/myapp_test_seeds\n"
        "          QUEUE_DATABASE_URL: postgres://postgres:password@localhost:5432/myapp_test_seeds_queue\n"
        "          POSTGRES_PASSWORD: password\n"
        "          REDIS_URL: redis://localhost:6379/0\n"
        "        run: |\n"
        "          bin/rails db:create\n"
        "          bin/rails db:schema:load\n"
        "          bin/rails db:test:prepare\n"
        "          bin/rails linestamp:validate_imports\n"
        "\n"
    )
    anchor = "  test:\n    runs-on: [self-hosted, sakura-vps]\n"
    if anchor not in s:
        raise SystemExit("ci: test ジョブのアンカーが見つからない — 手動確認が必要")
    s = s.replace(anchor, job + anchor, 1)
    print("ci: seed-check ジョブを test の直前に追加")

# notify / dispatch_deploy の needs に seed-check を追加(両方/冪等)
old_needs = "needs: [scan_ruby, lint, workflow-check, job-check, route-check, test]"
new_needs = "needs: [scan_ruby, lint, workflow-check, job-check, route-check, seed-check, test]"
if old_needs in s:
    n = s.count(old_needs)
    s = s.replace(old_needs, new_needs)
    print("ci: needs に seed-check を追加(%d 箇所)" % n)
elif new_needs in s:
    print("ci: needs は既に seed-check を含む — スキップ")
else:
    raise SystemExit("ci: needs 行のアンカーが見つからない — 手動確認が必要")

open(p, "w", encoding="utf-8").write(s)
PY

echo "==> docs/linestamp/MASTER_SLUGS.md を作成(冪等・ruby 無しで読める slug 辞書)"
mkdir -p docs/linestamp
DOC=docs/linestamp/MASTER_SLUGS.md
if [ -f "$DOC" ]; then
  echo "doc: 既に存在 — スキップ(更新したい場合は手で消して再実行)"
else
  cat > "$DOC" <<'MD'
# Linestamp master slug 一覧（seed 作成用の正解辞書）

seed ファイル（`db/seeds/linestamp/imports/pending/*.rb`）で使える slug の一覧。
**ここに無い slug を書くと `ArgumentError: Unknown ... slug` で apply が失敗する。**

> 出典: `db/seeds/linestamp/masters.rb`（`Linestamp::Seeds.call`）。
> master を増減したらこの表も更新すること。CI の `seed-check`（`rake linestamp:validate_imports`）が
> 実際の pending seed を eval して検証するため、ズレや typo はマージ前に赤くなる。

## communication themes（`attach_communication_themes!` / `primary_communication_theme`）

| slug | 名前 | 説明 |
|---|---|---|
| `remote_work_report` | 在宅ワーク報告 | 在宅勤務中の状況を相手に伝える |
| `gratitude` | 感謝 | ありがとうの気持ちを伝える |
| `apology` | 謝罪 | 申し訳なさを和らげて伝える |
| `agreement` | 相槌 | 了解・OK・うん |
| `encouragement` | 励まし | 相手を元気づける |
| `greeting_morning` | おはよう | 朝の挨拶 |
| `greeting_night` | おやすみ | 夜の挨拶 |
| `confirm_meetup` | 待ち合わせ確認 | 今どこ?何時? |
| `on_the_way` | 今行く | 移動中の連絡 |
| `meal_invitation` | 食事の誘い | ご飯行こう |
| `friendly_tease` | 相手をいじる | 軽い冗談・からかい |
| `appreciation_for_effort` | ねぎらい | お疲れさま系 |
| `need_focus` | 集中したい | 今は構わないで |
| `need_break` | 休憩したい | ちょっと休む |
| `quick_answer` | 簡易回答 | はい/いいえ/わかった |
| `urgent_contact` | 緊急連絡 | すぐ確認して系 |
| `status_busy` | 忙しいアピール | 今手が離せない |
| `celebration` | お祝い | おめでとう |

## attribute values（`attach_attribute_values!(brand, {tone:, motif:, demographic:, setting:})`）

軸（axis）は `tone` / `motif` / `demographic` / `setting` の4つ。

### tone（トーン）
`gentle`(ゆるい) `neat`(きっちり) `surreal`(シュール) `cute`(かわいい) `cool`(かっこいい) `stylish`(おしゃれ) `funny`(おもしろい) `elegant`(上品)

### motif（モチーフ）
`animal`(動物) `food`(食べ物) `plant`(植物) `human`(人物) `monster`(モンスター) `abstract`(抽象) `vehicle`(乗り物) `tool`(道具)

### demographic（デモグラフィ）
`age_10s`(10代) `age_20s`(20代) `age_30s`(30代) `age_40s`(40代) `age_50plus`(50代以上) `for_male`(男性向け) `for_female`(女性向け) `unisex`(性別不問) `business_user`(ビジネス層) `student`(学生)

### setting（シーン）
`home`(家庭) `remote_work`(在宅) `office`(オフィス) `with_friends`(友達同士) `with_lover`(恋人) `with_family`(家族) `boss_subordinate`(上司部下) `with_customer`(お客様)

## seed 作成の必須ルール（落とし穴）

- **1 ブランド = 1 ファイル**。`upsert_brand!` → `attach_*` → `create_pack!(... stamps: [8件])` を1ブロックに同梱する。
- **stamp はちょうど 8 件**（初回 Pack）。
- 各 stamp の `primary_communication_theme` は、その Brand に `attach_communication_themes!` した slug の **いずれかと一致**させる。
- `research_slug` は**本番に apply 済みの research** を指すこと。未 apply の research を指すと本番 apply で `Unknown Research slug` になる。
  （CI の `seed-check` は research をスタブ化して構造を検証するので、ここだけは CI を通っても本番で落ちうる点に注意）
- `brand_prompt` / `sheet_prompt` / `prompt` は**埋めない**（after_commit が自動合成する。埋めると合成がスキップされる）。
- `background_color_for_gen` は触らない（モデルで `#3CB371` 固定）。世界観カラーは `primary_color` へ。
- 投入前に `bin/rails linestamp:brand_collision` で既存ブランドとの被りを確認する。

## identity_axes のキー（`upsert_brand!(identity_axes: {...})`・差別化6軸+2）

`silhouette` / `name_origin` / `signature` / `signature_color` / `desire_weakness` / `voice` / `behavior`
（使わない軸は空でよい。空はプロンプトに出ない）
MD
  echo "doc: 作成 $DOC"
fi

echo "==> commit & push"
git add -A
if git diff --cached --quiet; then
  echo "差分なし — 既に適用済みのようです。push をスキップ。"
else
  git commit -m "ci(linestamp): pending seed をマージ前に検証する seed-check を追加

CI(rspec)は apply_imports spec が実 pending を eval 前に applied 扱いにする
ため、slug ミスや構造エラーが本番 apply で初めて落ちていた。rake
linestamp:validate_imports を新設し、masters を seed して各 pending を
ROLLBACK トランザクション内で実際に eval(research_slug はスタブ化)して
unknown slug / 構造エラーを検出。CI に seed-check ジョブを追加し
notify / dispatch_deploy の needs に組み込みマージ前にブロックする。
ruby 無し環境向けに docs/linestamp/MASTER_SLUGS.md(slug 辞書)も追加。"
  git push origin main
  echo "push 完了。CI 通過後に自動デプロイされます。"
fi
