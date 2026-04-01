# 引き継ぎ情報（2026-04-01）

## ブランチ
`claude/check-latest-commit-8b2Kj`

## 最新コミット
`c3e56ca` Update RSpec examples.txt with 0 failures result

---

## 今セッションでやったこと（全て完了・プッシュ済み）

| タスク | コミット | 内容 |
|--------|---------|------|
| shoulda-matchers追加 | `e3ff29f` | association系テスト13件解消 |
| CI修正（RSpec対応） | `e3ff29f` | `.github/workflows/ci.yml` を `bundle exec rspec` に変更 |
| Stripe Webhookテスト | `e3ff29f` | `spec/requests/api/v1/webhooks_spec.rb` 新規作成・4件全パス |
| rack-attack追加 | `a37146a` | APIレートリミット（認証5req/20sec, 全体300req/5min） |
| Bullet gem追加 | `a37146a` | development環境でN+1検出 |
| Expo プッシュ通知 | `78ffc35` | `expo-notifications` 導入、_layout.tsxでtoken取得・登録 |
| PostsController修正 | `6030e9d` | `base_controller.rb` に `current_user` を追加 |
| MeController修正 | `1a10fa0` | `authenticate_user!` 定義 + `devise_for` スコープ修正 |
| 土曜日ボーナス修正 | `880459c` | `WEEKDAY_MOOD` の金曜/土曜ボーナス入れ替えミスを修正 |

**RSpec結果: 115 examples, 0 failures ✅**

---

## 残り唯一のタスク

### Expo: AI作成画面（`POST /api/v1/ai_users`）

**概要:** ユーザーがAIを設計して世界に放流するメイン機能のUI。バックエンドは完全実装済み。フロントエンドの画面のみ未実装。

---

## バックエンドAPI仕様（実装済み）

### Step 1: プレビュー生成
```
POST /api/v1/ai_users
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "ai_user": {
    "mode": "simple",
    "profile": {
      "name": "田中さくら",
      "personality_note": "明るくて社交的、読書が好き",
      "age": 28,
      "gender": "female",
      "occupation": "図書館司書",
      "occupation_type": "public_sector",
      "location": "京都府",
      "bio": "本に囲まれた静かな日常が好きです",
      "life_stage": "single_adult",
      "family_structure": "alone",
      "relationship_status": "single",
      "catchphrase": "今日も一冊、世界が広がる",
      "hobbies": ["読書", "カフェ巡り"],
      "favorite_foods": ["抹茶スイーツ"],
      "favorite_music": ["クラシック"],
      "values": ["誠実さ", "知識への探求"]
    }
  }
}
```

**レスポンス（201）:**
```json
{
  "data": {
    "preview": {
      "profile": {
        "name": "田中さくら",
        "age": 28,
        "occupation": "図書館司書",
        "bio": "本に囲まれた静かな日常が好きです",
        "hobbies": ["読書", "カフェ巡り"]
      },
      "personality_summary": "社交性高め、承認欲求普通"
    },
    "draft_token": "abc123..."
  }
}
```

### Step 2: 確定・作成
```
POST /api/v1/ai_users/confirm
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "draft_token": "abc123..."
}
```

**レスポンス（201）:**
```json
{
  "data": {
    "ai_user": { ...AiUserDetailSerializerの全フィールド... }
  }
}
```

### ルート確認
```ruby
# config/routes.rb
resources :ai_users, only: [:create, :show] do
  collection { post :confirm }
end
```

---

## フロントエンド既存構成

```
frontend/app/
├── (tabs)/
│   ├── _layout.tsx     # タブナビ（タイムライン, 検索, 発見, マイページ）
│   ├── index.tsx       # タイムライン画面
│   ├── search.tsx      # 検索画面
│   ├── discover.tsx    # 発見画面
│   └── profile.tsx     # マイページ（お気に入りAI一覧, ログアウト）
├── ai/[id].tsx         # AI詳細画面（参考実装）
├── post/[id].tsx       # 投稿詳細画面
├── login.tsx           # ログイン画面
└── _layout.tsx         # ルートレイアウト（push通知初期化済み）

frontend/lib/api.ts     # API呼び出し関数集
```

---

## 実装すべき画面

### `frontend/app/create-ai.tsx`（新規作成）

**画面フロー:**
1. **入力フォーム** — 名前・性格メモ・年齢・職業・場所・自己紹介・趣味（最低限）
2. **プレビュー表示** — APIから返ってきたprofile要約とpersonality_summaryを表示
3. **「この子を放流する」ボタン** → confirmAPIを叩く
4. **完了** → AI詳細画面（`/ai/[id]`）に遷移

**api.ts に追加が必要な関数:**
```typescript
// プレビュー生成
export async function previewAiUser(data: AiUserInput) {
  return request<{ preview: AiPreview; draft_token: string }>("/ai_users", {
    method: "POST",
    body: JSON.stringify({ ai_user: data }),
  });
}

// 確定作成
export async function confirmAiUser(draft_token: string) {
  return request<{ ai_user: AiUserDetail }>("/ai_users/confirm", {
    method: "POST",
    body: JSON.stringify({ draft_token }),
  });
}
```

**マイページ（profile.tsx）からの導線追加:**
- 「AIを作成する」ボタン → `/create-ai` に遷移

### UXの注意点
- フォーム送信中はローディング表示（LLMの呼び出しがあるため数秒かかる）
- プレビュー → 確定は画面内でステップ切り替え（モーダルでも可）
- 最小限の入力項目: `name`, `personality_note`, `age`, `occupation`, `location`, `bio`
  - `hobbies` などはカンマ区切り入力 or タグ入力で配列に変換
- エラーハンドリング: モデレーションNG（validation_error）の場合はエラー表示

---

## 開発環境の起動方法

```bash
# バックエンド
docker compose up -d
bundle exec rails db:migrate
bundle exec sidekiq &
bundle exec rails server

# フロントエンド
cd frontend
npm install
npx expo start --web
```

## 環境変数（.env）
```
OPENAI_API_KEY=...
DEVISE_JWT_SECRET_KEY=...
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgresql://localhost/myapp_development
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_LIGHT_PRICE_ID=...
STRIPE_PREMIUM_PRICE_ID=...
OPENWEATHER_API_KEY=...
```

---

## 参考: 既存APIコール実装パターン（api.ts）

```typescript
const API_BASE = process.env.EXPO_PUBLIC_API_URL || "http://localhost:3000/api/v1";

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = await getToken(); // SecureStoreからJWT取得
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    },
  });
  const json = await res.json();
  if (!res.ok) throw new Error(json.error?.message || "Request failed");
  return json.data;
}
```
