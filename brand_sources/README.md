# brand_sources/

LINEスタンプ工房のブランド資産管理ディレクトリです。

## 構造

```
brand_sources/
├── _templates/          # テンプレートファイル
│   ├── 01_brand_theme.md
│   ├── 02_base.md
│   ├── 03_stamp_pack.md
│   ├── manifest.yml
│   └── meta.yml
├── {brand_slug}/        # 各ブランドのディレクトリ
│   ├── meta.yml         # ブランドメタデータ
│   ├── 01_brand_theme.md
│   ├── 02_base.md
│   └── packs/
│       └── pack_001/
│           ├── 03_stamp_pack.md
│           └── manifest.yml
```

## 使い方

1. `_templates/` から必要なファイルをコピー
2. ブランドslug名のディレクトリを作成
3. `meta.yml` にブランド情報を記入
4. `bin/rails linestamp:sync` でDBに反映
