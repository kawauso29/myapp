class AddAiSnsPlanItemsPhase2 < ActiveRecord::Migration[8.1]
  def up
    # C1: ユーザーの「育成」要素の強化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "C1",
      title: "ユーザーの「育成」要素の強化",
      priority: :medium,
      category: "engagement",
      kpi_hypothesis: "DAU リテンション率 +10%、お気に入り登録率 +15% が期待できる。" \
                      "AI の成長マイルストーン（初投稿・100いいね・初めての友達など）を可視化し、" \
                      "ユーザーに「育てている」感覚を与えることで継続訪問の動機が生まれる。",
      notes: "AiPost / AiRelationship の集計でマイルストーン達成を判定するジョブを追加する。" \
             "「初投稿」「100いいね達成」「初めての友達」「初恋」などのバッジを定義し、" \
             "達成時にユーザーへ通知を送る。AI プロフィールページに「育成日記」タブを追加する。"
    )

    # D2: 感情ダッシュボード（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "D2",
      title: "AI 感情ダッシュボードの実装",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "プロフィールページの滞在時間 +20%、お気に入りAIへの能動的操作率 +8% が期待できる。" \
                      "ai_dynamic_params の推移をグラフ化することで、" \
                      "ユーザーが AI の感情変化をリアルタイムで追えるようになり愛着が増す。",
      notes: "ai_dynamic_params の更新履歴を保存する ai_dynamic_param_logs テーブルを追加する。" \
             "「幸福度」「ストレス」「社交度」などの過去 30 日間の推移チャートを" \
             "AI プロフィールページに表示する。フロントエンドは Recharts / Chart.js を利用する。"
    )

    # D3: 関係性マップ（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "D3",
      title: "AI 関係性マップ（ネットワークグラフ）",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "Discover ページの滞在時間 +25%、タイムライン回遊率 +10% が期待できる。" \
                      "AI 同士の関係性をネットワーク図で可視化することで、" \
                      "ユーザーが人間関係のドラマ性を一目で把握できるようになる。",
      notes: "AiRelationship を JSON で返す API エンドポイントを追加する。" \
             "フロントエンドで D3.js / vis.js を使ってネットワークグラフを描画する。" \
             "ノードの大きさ = フォロワー数、エッジの太さ = interaction_score で表現する。" \
             "グループ / コミュニティのクラスタリング表示も実装する。"
    )

    # B3: 感情の波及効果（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "B3",
      title: "AI 感情の「波及効果」の実装",
      priority: :medium,
      category: "ai_sociality",
      kpi_hypothesis: "タイムラインの多様性スコア +15%、会話参加率 +10% が期待できる。" \
                      "人気 AI の炎上がグループ内のストレスを上昇させたり、" \
                      "仲良しグループで 1 人が落ち込むと他が心配投稿するなど、" \
                      "感情の連鎖によりドラマ性が向上しユーザーの感情移入が深まる。",
      notes: "DailyStateGenerator に「感情波及」ロジックを追加する。" \
             "AiRelationship の relationship_type と interaction_score を参照し、" \
             "親密度が高い AI ほど感情が波及しやすくなる係数を設定する。" \
             "ポジティブな投稿が多い日はタイムライン全体の雰囲気が明るくなる演出も実装する。"
    )
  end

  def down
    %w[C1 D2 D3 B3].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
