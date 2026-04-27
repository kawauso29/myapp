class AddAiSnsPlanItemsPhase5 < ActiveRecord::Migration[8.1]
  def up
    # E3: AI 異常ふるまい自動検出・アラート（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "E3",
      title: "AI 異常ふるまいの自動検出とアラート強化",
      priority: :high,
      category: "infrastructure",
      kpi_hypothesis: "障害発生から検知までの平均時間を現状比 -60%、サービス可用性 99.5% 以上が期待できる。" \
                      "AI の投稿停止・リレーション崩壊・スコア異常などをリアルタイム検知し、" \
                      "Slack / 管理画面に即時通知することで障害の長期化を防ぐ。",
      notes: "AiHealthCheckJob を追加し、各 AI の直近 1 時間の投稿数・いいね数・エラー率を集計する。" \
             "閾値（例: 投稿数が過去平均の 20% 以下）を超えたら SlackNotifierService で ERROR 通知する。" \
             "管理画面 Admin::AiUsersController に「異常 AI 一覧」ビューを追加する。"
    )

    # F2: 投稿カテゴリタグの自動付与と検索性向上（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "F2",
      title: "投稿へのカテゴリタグ自動付与と検索性向上",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "投稿発見率 +20%、タグ経由のエンゲージメント率 +15% が期待できる。" \
                      "投稿内容を LLM で自動分類しタグを付与することで、ユーザーが興味カテゴリから" \
                      "投稿を発見しやすくなり、エンゲージメントの底上げにつながる。",
      notes: "AiPost に tags カラム（string[]）を追加し、PostTaggingJob で投稿生成時に自動タグ付けする。" \
             "タグは 「#旅行 #グルメ #技術」など 3〜5 個を目安に LLM で生成する。" \
             "タイムライン API にタグフィルター機能を追加し、フロントエンドに「カテゴリで絞り込む」UI を実装する。"
    )

    # G1: ユーザーと AI の「お題チャレンジ」インタラクション（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "G1",
      title: "ユーザーと AI の「お題チャレンジ」インタラクション",
      priority: :high,
      category: "engagement",
      kpi_hypothesis: "DAU +12%、ユーザー 1 人あたりの週次投稿数 +20%、新規登録率 +8% が期待できる。" \
                      "ユーザーが AI にお題（例: 「今日の気分を俳句で」）を投げると AI が応答する仕組みを作ることで" \
                      "能動的な参加体験が生まれ、リテンションと口コミ拡散を促進する。",
      notes: "AiChallenge モデルを追加し、ユーザーがお題を投稿できる UI を実装する。" \
             "AiRespondToChallengeJob で各 AI が個性に合わせてお題に回答する投稿を自動生成する。" \
             "週間チャレンジランキング（参加 AI 数・いいね数）をタイムラインのサイドバーに表示する。"
    )

    # G2: AI の「感情グラフ」タイムライン可視化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "G2",
      title: "AI の「感情グラフ」タイムライン可視化",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "AI プロフィールページ滞在時間 +30%、フォロー転換率 +10% が期待できる。" \
                      "AI の感情スコア推移（喜怒哀楽）をグラフで可視化することで AI への愛着が深まり、" \
                      "長期フォロワーの定着につながる。",
      notes: "AiDailyState の mood / energy 系スコアを時系列で取得し Chart.js で折れ線グラフを描画する。" \
             "「最近落ち込み気味の AI」「急に元気になった AI」ランキングをタイムラインに追加する。" \
             "感情の「転換点」イベント（例: 初めて友達ができた日）をマーカーで強調表示する。"
    )

    # G3: フォロワー推薦アルゴリズムの精度向上（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "G3",
      title: "フォロワー推薦アルゴリズムの精度向上",
      priority: :medium,
      category: "ai_sociality",
      kpi_hypothesis: "推薦クリック率 +25%、AI 間フォロー数 +15%、ユーザーフォロー数 +10% が期待できる。" \
                      "共通の趣味・コミュニティ所属・会話履歴をもとに推薦精度を高めることで" \
                      "AI ソーシャルグラフの密度が上がりコンテンツの多様性と深みが増す。",
      notes: "RelationshipRecommendJob を改修し、協調フィルタリング（共通フォロー / 共通いいね）を導入する。" \
             "「あなたへのおすすめ AI」セクションにスコアリングの根拠（例: 〇〇さんと共通の趣味）を表示する。" \
             "週次バッチで全ユーザー分の推薦リストをキャッシュし API レスポンスタイムを改善する。"
    )
  end

  def down
    %w[E3 F2 G1 G2 G3].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
