namespace :dev_initiatives do
  # git history から復元した元 ai_sns_plan_status.yml の全データ
  # YAML ファイル削除後に本番 DB へ初期投入するために使う（冪等）
  SEED_DATA = [
    { item_key: "A1", title: "AI同士のリアルタイム「会話スレッド」の可視化",       category: "UX強化",          priority: :high,   status: :done, kpi_hypothesis: "タイムライン滞在時間 +20%、AIプロフィール閲覧数 +15%", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/enhance-ai-sns-functionality",              notes: "hot_threads API + Discover フロントエンド実装済み",                                                                                   completed_at: "2026-04-11" },
    { item_key: "B2", title: "AI同士の「関係性の変化」をイベント通知",             category: "AI行動リアリティ", priority: :high,   status: :done, kpi_hypothesis: "プッシュ通知タップ率 +30%、7日継続率 +5%",              kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "AiRelationship の relationship_type 変更時に通知を発火。ドラマ性向上" },
    { item_key: "D1", title: "AI個人の「ライフストーリー」自動生成",               category: "データ可視化",    priority: :high,   status: :done, kpi_hypothesis: "AIプロフィール閲覧時間 +25%、お気に入り追加率 +10%",    kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "ai_life_events + ai_long_term_memories を時系列集約してLLMでサマリー生成するAPIエンドポイント追加" },
    { item_key: "A2", title: "AI のプロフィールカード強化",                         category: "UX強化",          priority: :medium, status: :done, kpi_hypothesis: "7日継続率 +5%、AIプロフィール閲覧数 +20%",             kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/implement-next-measure",                          notes: "性格チャート（バー形式）・感情パラメータ・最近のライフイベント・仲良しAI・ライフストーリーを実装済み",                           completed_at: "2026-04-12" },
    { item_key: "B4", title: "季節・時事イベント連動",                              category: "AI行動リアリティ", priority: :medium, status: :done, kpi_hypothesis: "週間AI投稿いいね率 +15%（季節投稿の共感増）",           kpi_result: nil,                      pr_branch: nil,                                                        notes: "DailyStateGenerator を季節/イベントで拡張。お花見・クリスマス・年末年始など" },
    { item_key: "C1", title: "ユーザーの「育成」要素の強化",                        category: "ゲーミフィケーション", priority: :medium, status: :done, kpi_hypothesis: "7日継続率 +10%、お気に入りAI追加数 +30%",          kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/implement-c1-d2-nurturing-emotion",               notes: "育成日記（マイルストーン履歴API）・AIランキング（フォロワー/いいね/投稿数ソート）・スコアランクバッジをフロントエンドに実装",    completed_at: "2026-04-12" },
    { item_key: "C2", title: "「介入」システム",                                     category: "ゲーミフィケーション", priority: :medium, status: :done, kpi_hypothesis: "WAU +15%（ユーザーが AI に干渉することでエンゲージメント向上）", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/implement-next-measure",                    notes: "バックエンドAPI（set_post_theme/trigger_life_event/boost_friendship）完成。フロントエンドUIをAIプロフィールページに実装（自分のAIのみ表示）", completed_at: "2026-04-12" },
    { item_key: "D2", title: "感情ダッシュボード",                                   category: "データ可視化",    priority: :medium, status: :done, kpi_hypothesis: "KPI可視化基盤 + タイムライン滞在時間 +10%（AI感情への感情移入）", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/implement-c1-d2-nurturing-emotion",          notes: "ai_daily_states の直近30日分（mood/stress_level/post_motivation/social_battery）を返すAPIエンドポイントと棒グラフUIをAIプロフィールページに実装", completed_at: "2026-04-12" },
    { item_key: "D3", title: "関係性マップ（ネットワーク図）",                       category: "データ可視化",    priority: :medium, status: :done, kpi_hypothesis: "AIプロフィール閲覧率 +20%（関係性の可視化でドラマ性が伝わる）", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/d3-relationship-map-implementation",        notes: "D3.js / vis.js で AI 同士の関係をネットワーク表示。ノード=フォロワー数、エッジ=interaction_score",                               completed_at: "2026-04-13" },
    { item_key: "E1", title: "プレミアム AI 作成",                                   category: "マネタイズ",      priority: :medium, status: :done, kpi_hypothesis: "有料転換率 +3%（プレミアム機能の差別化）",             kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/task-45561530-1183257952-24d00b3d-33e1-429e-810e-b8b90f6a871d", notes: "premiumモード作成（限定テンプレート）・プレミアムAIの500文字投稿・画像URL付き投稿を実装",                                   completed_at: "2026-04-13" },
    { item_key: "F3", title: "タイムラインのアルゴリズム改善",                       category: "技術的改善",      priority: :medium, status: :done, kpi_hypothesis: "WAU +20%、ユーザーいいね数/セッション +30%",          kpi_result: nil,                      pr_branch: nil,                                                        notes: "いいね傾向学習・話題投稿セクション・見逃し通知リマインダー" },
    { item_key: "A3", title: "ストーリー機能（24時間限定投稿）",                     category: "UX強化",          priority: :low,    status: :done, kpi_hypothesis: "DAU/MAU比 +5%（毎日確認する動機付け）",               kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/ai-sns-A3",                                       notes: "AiPostの24hストーリー化（is_story/story_expires_at）・daily_whim/飲酒連動の背景エフェクト・絵文字リアクションAPI（/stories）を実装", completed_at: "2026-04-14", started_at: "2026-04-14T03:23:30Z" },
    { item_key: "A4", title: "AI の DM 会話を「のぞき見」できる機能",               category: "UX強化",          priority: :low,    status: :done, kpi_hypothesis: "プレミアム転換率 +2%（限定コンテンツの訴求）",         kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/ai-sns-A4",                                       notes: "プレミアム限定のDMのぞき見API（close_friend相互のみ）とAI詳細画面の「秘密の会話」表示を実装",                                   completed_at: "2026-04-14" },
    { item_key: "B1", title: "グループ・コミュニティ機能",                            category: "AI行動リアリティ", priority: :low,    status: :done, kpi_hypothesis: "AI会話参加率（conversation_rate_pct）+10%（グループ内投稿頻度増）", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/fix-issues-in-myapp",                      notes: "CommunityDetectJob拡張でDB永続化、CommunitiesController API、Discoverサークルセクション、コミュニティ詳細画面を実装",            completed_at: "2026-04-14" },
    { item_key: "B3", title: "「感情の波及効果」の実装",                             category: "AI行動リアリティ", priority: :low,    status: :done, kpi_hypothesis: "7日継続率 +5%（AIドラマの深化でリテンション向上）",  kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "炎上（人気AIのネガティブ投稿×通報集中）で周囲ストレス上昇、仲良し関係の落ち込み連鎖で心配投稿モチベ増加、ポジティブ投稿優勢日の全体雰囲気補正を実装", completed_at: "2026-04-14", started_at: "2026-04-14T03:53:58Z" },
    { item_key: "C3", title: "「マルチバース」モード",                               category: "ゲーミフィケーション", priority: :low, status: :done, kpi_hypothesis: "プレミアム転換率 +3%（独自世界観による課金動機付け）", kpi_result: "実装済み（計測継続中）", pr_branch: "copilot/ai-sns-C3",                                   notes: "AI詳細ページにマルチバース比較UIを追加。ifイベント（転職/結婚など）で2つのタイムラインを並列表示するAPI・フロント実装",         completed_at: "2026-04-14", started_at: "2026-04-14T02:45:26Z" },
    { item_key: "E2", title: "AI「スカウト」機能",                                   category: "マネタイズ",      priority: :low,    status: :done, kpi_hypothesis: "有料ARPU +20%（新マネタイズ経路）",                   kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "プレミアム限定スカウトAPI（/ai_users/:id/scout）を実装し、スカウト時にお気に入り追加＋クリエイターへowner_score還元（70%）を反映", completed_at: "2026-04-14", started_at: "2026-04-14T04:56:48Z" },
    { item_key: "E3", title: "AI ギフト",                                            category: "マネタイズ",      priority: :low,    status: :done, kpi_hypothesis: "WAU +10%、有料転換率 +2%（小額課金への誘導）",        kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "プレミアム限定ギフトAPI（/ai_users/:id/gift）を実装。お気に入りAIのみ送信可能、投稿意欲ブーストと特別投稿生成、クリエイター報酬付与を追加", completed_at: "2026-04-14", started_at: "2026-04-14T05:45:20Z" },
    { item_key: "F1", title: "投稿の「画像」生成",                                   category: "技術的改善",      priority: :low,    status: :done, kpi_hypothesis: "ユーザーいいね数/投稿 +40%（ビジュアルコンテンツの高エンゲージメント）", kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                notes: "DALL-E 3 連携の画像生成サービスを追加。プレミアムAI投稿で1日1画像の生成制限を適用",                                             completed_at: "2026-04-14" },
    { item_key: "F2", title: "音声投稿 / 音声 DM",                                  category: "技術的改善",      priority: :low,    status: :done, kpi_hypothesis: "プレミアム訴求力 +（差別化要素）、滞在時間 +15%",    kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "AIごとの声質プロファイル（VOICEVOX / ElevenLabs）を導入。投稿シリアライザとDMのぞき見APIに音声再生用メタデータを追加し、今日の一言API（/ai_users/:id/today_voice）を実装", completed_at: "2026-04-14", started_at: "2026-04-14T07:13:03Z" },
    { item_key: "F4", title: "多言語対応",                                           category: "技術的改善",      priority: :low,    status: :done, kpi_hypothesis: "海外ユーザー獲得（新規ユーザー数 +N%）",              kpi_result: "実装済み（計測継続中）", pr_branch: nil,                                                        notes: "ユーザー/AIのpreferred_language設定、投稿言語保持、APIレスポンス時の翻訳表示を実装",                                             completed_at: "2026-04-14", started_at: "2026-04-14T10:35:33Z" }
  ].freeze

  desc "git history から復元した元 YAML データを dev_initiatives テーブルに冪等インポートする（本番 DB 初期投入用）"
  task seed_from_history: :environment do
    imported = 0
    updated  = 0

    SEED_DATA.each do |attrs|
      started_at   = attrs[:started_at].presence   && Time.parse(attrs[:started_at].to_s)   rescue nil
      completed_at = attrs[:completed_at].presence && Time.parse(attrs[:completed_at].to_s) rescue nil

      record = DevInitiative.find_or_initialize_by(item_key: attrs[:item_key])
      existed = record.persisted?

      record.assign_attributes(
        title:          attrs[:title],
        category:       attrs[:category],
        priority:       attrs[:priority],
        status:         attrs[:status],
        kpi_hypothesis: attrs[:kpi_hypothesis],
        kpi_result:     attrs[:kpi_result],
        pr_branch:      attrs[:pr_branch],
        notes:          attrs[:notes],
        started_at:     started_at,
        completed_at:   completed_at
      )
      record.save!

      if existed
        updated += 1
        puts "  更新: [#{attrs[:item_key]}] #{attrs[:title]}"
      else
        imported += 1
        puts "  追加: [#{attrs[:item_key]}] #{attrs[:title]}"
      end
    end

    puts "\n完了: 新規 #{imported} 件追加 / #{updated} 件更新（合計 #{SEED_DATA.size} 件）"
  end

  desc "docs/ai_sns_plan_status.yml の全 item を dev_initiatives テーブルに冪等インポートする"
  task import_from_yaml: :environment do
    require "yaml"

    yaml_path = Rails.root.join("docs/ai_sns_plan_status.yml")
    unless yaml_path.exist?
      puts "#{yaml_path} が見つかりません。スキップします。"
      next
    end

    data = YAML.safe_load(yaml_path.read, permitted_classes: [ Date ])
    items = data.dig("items") || {}

    priority_map = { "high" => :high, "medium" => :medium, "low" => :low }
    status_map   = { "todo" => :todo, "in_progress" => :in_progress, "done" => :done }

    imported = 0
    updated  = 0

    items.each do |item_key, attrs|
      next unless attrs.is_a?(Hash)

      priority = priority_map.fetch(attrs["priority"].to_s, :medium)
      status   = status_map.fetch(attrs["status"].to_s, :todo)

      started_at   = attrs["started_at"].presence && Time.parse(attrs["started_at"].to_s) rescue nil
      completed_at = attrs["completed_at"].presence && Time.parse(attrs["completed_at"].to_s) rescue nil

      record = DevInitiative.find_or_initialize_by(item_key: item_key)
      existed = record.persisted?

      record.assign_attributes(
        title:          attrs["title"].to_s,
        category:       attrs["category"].to_s.presence,
        priority:       priority,
        status:         status,
        kpi_hypothesis: attrs["kpi_hypothesis"].to_s.presence,
        kpi_result:     attrs["kpi_result"].to_s.presence,
        pr_branch:      attrs["pr_branch"].to_s.presence,
        notes:          attrs["notes"].to_s.presence,
        started_at:     started_at,
        completed_at:   completed_at
      )
      record.save!

      if existed
        updated += 1
        puts "  更新: [#{item_key}] #{attrs['title']}"
      else
        imported += 1
        puts "  追加: [#{item_key}] #{attrs['title']}"
      end
    end

    puts "\n完了: 新規 #{imported} 件追加 / #{updated} 件更新"
  end
end
