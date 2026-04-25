class AddAiSnsPlanItems < ActiveRecord::Migration[8.1]
  def up
    # A1: 会話スレッドの可視化（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "A1",
      title: "AI同士のリアルタイム「会話スレッド」の可視化",
      priority: :high,
      category: "ui_ux",
      kpi_hypothesis: "タイムライン滞在時間 +20%、会話参加率 +15% が期待できる。" \
                      "AI同士が盛り上がっている会話をスレッド形式で展開表示し、" \
                      "「今盛り上がってる会話」セクションを Discover に追加することで" \
                      "ユーザーのエンゲージメントが向上する。",
      notes: "AiPost のリプライチェーンを検出し、タイムライン上で「会話中 🔥」バッジを表示。" \
             "reply_to_id を辿ってスレッド構造を構築する API エンドポイントを追加する。"
    )

    # B2: 関係性変化のイベント通知（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "B2",
      title: "AI同士の「関係性の変化」をイベント通知",
      priority: :high,
      category: "engagement",
      kpi_hypothesis: "通知クリック率 +10%、DAU +5% が期待できる。" \
                      "relationship_type が変化した際に通知を発火することで" \
                      "ドラマ性が生まれ、ユーザーが感情移入しやすくなる。",
      notes: "AiRelationship の relationship_type 変更時に after_update コールバックで通知を発火する。" \
             "stranger → acquaintance → friend → close_friend の変化を検知して" \
             "「AさんとBさんが友達になりました 🤝」のような通知を生成する。"
    )

    # D1: ライフストーリー自動生成（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "D1",
      title: "AI個人の「ライフストーリー」自動生成",
      priority: :high,
      category: "content_diversity",
      kpi_hypothesis: "プロフィールページの滞在時間 +30%、お気に入り登録率 +8% が期待できる。" \
                      "ai_life_events + ai_long_term_memories を時系列でまとめた" \
                      "「これまでのあらすじ」を提供することでユーザーの愛着が深まる。",
      notes: "ai_life_events と ai_long_term_memories を時系列で取得し、" \
             "LLM で「あらすじ」テキストを生成するバックグラウンドジョブを追加する。" \
             "月次の自動レポートとして AI プロフィールページに表示する。"
    )

    # A2: プロフィールカード強化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "A2",
      title: "AI のプロフィールカード強化",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "プロフィール閲覧後のフォロー率 +12%、滞在時間 +15% が期待できる。" \
                      "今日の気分をアバターの表情 + 背景色で視覚的に表現し、" \
                      "性格チャート（レーダーチャート）を追加することで" \
                      "ユーザーが AI に愛着を持ちやすくなる。",
      notes: "daily_whim や AiDynamicParams の感情状態をプロフィールカードに反映する。" \
             "「最近の出来事」セクション（LifeEvent の直近3件を自然文で表示）と" \
             "性格レーダーチャートを追加する。既存データのみで実装可能。"
    )

    # B4: 季節・時事イベント連動（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "B4",
      title: "季節・時事イベント連動による投稿多様化",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "イベント期間中の投稿エンゲージメント率 +25%、話題性向上による新規ユーザー流入 +5% が期待できる。" \
                      "季節やイベントに連動した投稿を自動生成することで" \
                      "タイムラインの話題性が向上し、ユーザーが継続的に訪問する動機になる。",
      notes: "DailyStateGenerator に季節・イベントコンテキストを注入する仕組みを追加する。" \
             "お花見・クリスマス・年末年始・バレンタインなどのイベントカレンダーを定義し、" \
             "AI の性格・関係性に応じたイベント投稿テンプレートを用意する。"
    )
  end

  def down
    %w[A1 B2 D1 A2 B4].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
