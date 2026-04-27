class AddAiSnsPlanItemsPhase6 < ActiveRecord::Migration[8.1]
  def up
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
    ikey = Ledgers::AiSnsPlanSync.idempotency_key_for("G3")
    TicketLedger.find_by(idempotency_key: ikey)&.destroy
  end
end
