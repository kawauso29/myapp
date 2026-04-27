class AddAiSnsPlanItemsPhase4 < ActiveRecord::Migration[8.1]
  def up
    # A4: AI の DM 会話を「のぞき見」できる機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "A4",
      title: "AI の DM 会話「のぞき見」機能の実装",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "プレミアム転換率 +5%、タイムライン滞在時間 +20% が期待できる。" \
                      "親密度の高い 2 体の AI の DM を（本人の許可設定で）閲覧可能にすることで" \
                      "AI への感情移入が深まり、プレミアム機能のマネタイズにもつながる。",
      notes: "AiDirectMessage テーブルに is_public / public_until カラムを追加する。" \
             "AI が一定以上の親密度に達したとき、互いに許可設定で DM を公開可能にする。" \
             "フロントエンドに「秘密の会話を見る 🔓」UI を追加し、プレミアム機能として実装する。"
    )

    # B1: グループ・コミュニティ機能（★☆☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "B1",
      title: "AI グループ・コミュニティの可視化と活性化",
      priority: :low,
      category: "ai_sociality",
      kpi_hypothesis: "グループ内会話参加率 +30%、DAU +10% が期待できる。" \
                      "CommunityDetectJob で自動検出されているコミュニティを「サークル」として可視化し、" \
                      "グループ内の投稿頻度を高めることでコンテンツの多様性と深みが増す。",
      notes: "既存の CommunityDetectJob の検出結果を AiGroup モデルで永続化する。" \
             "テーマ・メンバー・グループ投稿を管理し、タイムラインに「グループ盛り上がり中」セクションを追加する。" \
             "ユーザーもグループをフォローできるようにする。"
    )

    # C3: 「マルチバース」モード（★☆☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "C3",
      title: "「マルチバース」モード: AI の平行世界シミュレーション",
      priority: :low,
      category: "content_diversity",
      kpi_hypothesis: "長期リテンション率 +8%、SNS シェア率 +15% が期待できる。" \
                      "「もし AI が転職していたら？」などの if 世界を分岐させて比較表示することで" \
                      "ユーザーの創造的関与が深まり、独自コンテンツとして拡散力が生まれる。",
      notes: "AiProfile に branch_from_ai_id カラムを追加し、分岐 AI を管理する。" \
             "分岐点以降の LifeEvent を別軌道で生成するバックグラウンドジョブを実装する。" \
             "2 つの平行世界のタイムラインを比較表示する UI を追加する。"
    )

    # F1: 投稿の「画像」生成（★☆☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "F1",
      title: "AI 投稿へのコスト効率の良い画像自動生成",
      priority: :low,
      category: "content_diversity",
      kpi_hypothesis: "投稿エンゲージメント率 +35%、新規ユーザー登録率 +5% が期待できる。" \
                      "投稿にマッチした画像を自動生成することでビジュアルインパクトが向上し、" \
                      "SNS としての訴求力が大幅に増す。コスト管理のため頻度制限を設ける。",
      notes: "DALL-E 3 / Stable Diffusion で投稿テキストから画像を生成する ImageGenerateJob を追加する。" \
             "コスト管理のため 1 日あたりの生成枚数に上限を設ける（例: 全 AI 合計 20 枚/日）。" \
             "AiPost に image_url / image_generated_at カラムを追加して管理する。"
    )

    # F3: タイムラインのアルゴリズム改善（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "F3",
      title: "タイムラインのパーソナライズアルゴリズム改善",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "タイムライン滞在時間 +25%、いいね率 +10%、DAU リテンション +8% が期待できる。" \
                      "ユーザーの「いいね傾向」から興味を学習し、おすすめ投稿を優先表示することで" \
                      "パーソナライズされた体験を提供しリテンション向上につながる。",
      notes: "UserInterest モデルを追加し、いいね履歴から関心カテゴリを集計する。" \
             "タイムライン取得 API に interest_weight を加味したランキングロジックを実装する。" \
             "「話題の投稿」（短時間でいいね急増）と「見逃し投稿」リマインダーセクションも追加する。"
    )
  end

  def down
    %w[A4 B1 C3 F1 F3].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
