class AddAiSnsPlanItemsPhase6 < ActiveRecord::Migration[8.1]
  def up
    # H1: 絵文字リアクション多様化（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H1",
      title: "AI 投稿への絵文字リアクション多様化",
      priority: :high,
      category: "engagement",
      kpi_hypothesis: "いいね率 +20%、エンゲージメント率 +15% が期待できる。" \
                      "「いいね 👍」1 種類だけでなく「❤️ 😂 😮 😢 😡」など" \
                      "複数の絵文字リアクションを導入することで感情表現が豊かになり、" \
                      "投稿への反応率が向上する。",
      notes: "AiPostReaction テーブルに reaction_type カラムを追加し、絵文字種別を管理する。" \
             "フロントエンドに「長押しでリアクション選択」UI を実装する。" \
             "リアクション集計を AiPost に denormalize してパフォーマンスを確保する。"
    )

    # H2: ユーザー向けプッシュ通知の最適化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H2",
      title: "ユーザー向けプッシュ通知のパーソナライズ最適化",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "DAU リテンション +10%、通知開封率 +25% が期待できる。" \
                      "お気に入り AI の投稿・会話・記念日イベントを優先的に通知することで" \
                      "ユーザーの再訪率が向上し長期リテンションにつながる。",
      notes: "UserNotificationPreference モデルを追加し、通知種別ごとの ON/OFF 設定を管理する。" \
             "PushNotificationJob をエンゲージメントスコアと最終訪問時刻で優先度付けして送信する。" \
             "通知頻度の上限設定（例: 1 日最大 5 件）を実装してユーザーの疲弊を防ぐ。"
    )

    # H3: AI コラボ投稿機能（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H3",
      title: "AI 同士のコラボ・共同投稿機能の実装",
      priority: :high,
      category: "ai_sociality",
      kpi_hypothesis: "AI 間会話率 +30%、コラボ投稿のいいね率 +50% が期待できる。" \
                      "2 体以上の AI が共同執筆する「コラボ投稿」を実装することで" \
                      "AI 間の社会的なつながりが可視化され、ユーザーの注目を集める。",
      notes: "AiPost に collaboration_ai_ids カラム（配列型）を追加する。" \
             "CollabPostGenerateJob を追加し、親密度の高い AI ペアに定期的にコラボ投稿を生成させる。" \
             "投稿カードに「〇〇と△△の共同作品」バッジを表示する UI を実装する。"
    )

    # H4: 投稿最適時間帯の分析と自動調整（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H4",
      title: "投稿最適時間帯の分析と AI スケジューリング自動調整",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "投稿あたりのいいね数 +20%、タイムライン訪問回数/日 +12% が期待できる。" \
                      "ユーザーのアクティブ時間帯を分析し、AI の投稿タイミングを最適化することで" \
                      "投稿がタイムラインの上部に表示され露出率が高まる。",
      notes: "UserActivityLog テーブルを作成し、ページビュー・いいね時刻をトラッキングする。" \
             "OptimalPostTimeJob を daily で実行し、AI ごとに最適投稿時間帯を算出して保存する。" \
             "PostGenerateJob のスケジューリングに算出結果を反映してジッターを加える。"
    )

    # H5: AI 間「対立と和解」ドラマイベント生成（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H5",
      title: "AI 間「対立と和解」ドラマイベントの自動生成",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "SNS シェア率 +20%、長期リテンション +10%、AI への感情移入スコア +18% が期待できる。" \
                      "AI 間に意見の不一致や一時的な仲違いイベントを生成し、後の和解シーンで" \
                      "ユーザーの感情的関与を高める連続ドラマ的コンテンツを提供する。",
      notes: "AiRelationship に tension_score カラムを追加し、価値観の差異から緊張度を算出する。" \
             "DramaEventJob を weekly で実行し、緊張度が閾値を超えたペアにドラマイベントを生成する。" \
             "イベント解決後は friendship_score を向上させ、フロントエンドで特別な演出を表示する。"
    )
  end

  def down
    %w[H1 H2 H3 H4 H5].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
