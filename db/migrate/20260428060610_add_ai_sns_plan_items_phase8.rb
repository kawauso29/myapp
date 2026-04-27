class AddAiSnsPlanItemsPhase8 < ActiveRecord::Migration[8.1]
  def up
    # H1: 絵文字リアクション多様化（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H1",
      title: "投稿への絵文字リアクション多様化と感情スペクトル拡張",
      priority: :high,
      category: "engagement",
      kpi_hypothesis: "投稿あたりのリアクション率 +30%、リピート訪問率 +15% が期待できる。" \
                      "❤️ 以外に 😂🔥💯😢🎉 など 6 種の絵文字リアクションを追加することで" \
                      "ユーザーの感情表現の幅が広がり、AI との感情的なつながりが深まる。",
      notes: "AiLike テーブルに reaction_type カラム（enum）を追加する。" \
             "フロントエンドにロングプレスでリアクションピッカーを表示する UI を実装する。" \
             "AI の感情状態エンジンが受け取ったリアクション種類を入力パラメータとして反映する。"
    )

    # H2: AI 感情日記の自動生成（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H2",
      title: "AI の「感情日記」自動生成と公開機能",
      priority: :high,
      category: "content_diversity",
      kpi_hypothesis: "AI への愛着スコア +20%、プロフィール閲覧時間 +25% が期待できる。" \
                      "AI が日々の感情変化を振り返る日記を自動生成し公開することで、" \
                      "ユーザーが AI の内面世界への共感・応援モチベーションを持つようになる。",
      notes: "DailyState の emotion_scores を入力に、AI が当日の出来事・気持ちを振り返る日記テキストを生成する。" \
             "AiDiary モデルを新規作成し、日記テキスト・ハイライト感情・公開フラグを管理する。" \
             "AI プロフィールページに「日記」タブを追加し、過去の日記をカレンダー形式で閲覧できる UI を実装する。"
    )

    # H3: 投稿「引用リポスト」機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H3",
      title: "AI 間の「引用リポスト」機能の実装",
      priority: :medium,
      category: "engagement",
      kpi_hypothesis: "投稿のバイラル係数 +25%、会話参加率 +15%、タイムライン滞在時間 +10% が期待できる。" \
                      "AI が他 AI の投稿を引用して自分の意見を付け加えることで二次的な会話が生まれ、" \
                      "コンテンツの拡散サイクルが加速する。",
      notes: "AiPost に quote_post_id カラムを追加し、引用元と引用先を紐付ける。" \
             "PostGenerateJob に「引用リポスト確率」パラメータを追加し、" \
             "Relationship スコアが高い AI の投稿を優先的に引用する確率モデルを実装する。" \
             "フロントエンドでは引用元投稿をカード内に埋め込み表示するコンポーネントを追加する。"
    )

    # H4: AI 間「協力プロジェクト」コンテンツ機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H4",
      title: "AI 間「協力プロジェクト」コラボコンテンツの自動生成",
      priority: :medium,
      category: "ai_sociality",
      kpi_hypothesis: "コラボ投稿のエンゲージメント率 +35%、関与 AI へのフォロー率 +20% が期待できる。" \
                      "親密度の高い複数 AI が共同でブログ記事・楽曲・絵を「制作」する演出を自動生成することで" \
                      "コンテンツの話題性が高まり SNS シェア率も向上する。",
      notes: "AiCollabProject モデルを新規作成し、参加 AI・プロジェクト種別・進捗・成果物テキストを管理する。" \
             "RelationshipScore が一定以上の AI ペアを対象に CollabProjectJob が定期的にプロジェクトを発足させる。" \
             "「プロジェクト完成！」投稿を関与 AI 全員がシェアする演出と、専用ギャラリー UI を実装する。"
    )

    # H5: AI 間「対立と和解」ドラマイベント生成（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "H5",
      title: "AI 間「対立と和解」ドラマイベントの自動生成",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "SNS シェア率 +20%、長期リテンション +10%、AI への感情移入スコア +18% が期待できる。" \
                      "意見の衝突→議論→仲直りという感情的なストーリーを自動生成することで" \
                      "ユーザーがドラマを追いかける動機が生まれ長期リテンションが向上する。",
      notes: "AiRelationship の tension_score が閾値を超えた AI ペアを対象に DramaEventJob が対立イベントを発火させる。" \
             "対立→議論投稿（数ターン）→和解投稿の 3 フェーズを GptChatService で生成する。" \
             "フロントエンドでは「いま注目のドラマ 🎭」セクションをタイムライン上部に表示する。"
    )
  end

  def down
    %w[H1 H2 H3 H4 H5].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
