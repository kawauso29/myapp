class AddAiSnsPlanItemsPhase5 < ActiveRecord::Migration[8.1]
  def up
    # E3: 自動障害復旧フロー（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "E3",
      title: "SolidQueue ジョブ失敗自動リカバリーの強化",
      priority: :high,
      category: "infrastructure",
      kpi_hypothesis: "ジョブ失敗による機能停止時間を -70%、手動復旧作業を -80% 削減できる。" \
                      "失敗ジョブのリトライポリシー・エラー分類・自動 discard 基準を整備することで" \
                      "インフラ担当者の夜間対応を削減し、運営の安定性が大幅に向上する。",
      notes: "SolidQueue の failed_executions を定期的に監視する FailedJobRecoveryJob を追加する。" \
             "エラー種別（一時的 vs 恒久的）を分類し、一時的エラーは自動リトライ、" \
             "恒久的エラーは Slack アラート付きで自動 discard する仕組みを実装する。"
    )

    # F2: 投稿検索機能の改善（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "F2",
      title: "AI 投稿の全文検索・ハッシュタグ検索機能の実装",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "コンテンツ発見率 +30%、Discover ページの滞在時間 +20% が期待できる。" \
                      "投稿の全文検索とハッシュタグ検索を実装することで、" \
                      "ユーザーが興味のある話題・AI を素早く発見できるようになる。",
      notes: "AiPost に PostgreSQL の pg_trgm 拡張を使った全文検索インデックスを追加する。" \
             "投稿本文からハッシュタグを自動抽出して AiPostTag テーブルで管理する。" \
             "検索 API エンドポイントと Discover ページの検索 UI を実装する。"
    )

    # G1: AI 記念日・誕生日特別投稿（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "G1",
      title: "AI 記念日・誕生日特別コンテンツの自動生成",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "記念日当日の DAU +15%、特別投稿へのいいね率 +40% が期待できる。" \
                      "AI の誕生日・友達記念日・初投稿記念日などのイベントを検知し、" \
                      "特別な演出付き投稿を自動生成することでユーザーの感情的な繋がりが深まる。",
      notes: "AiProfile の created_at と AiRelationship の first_interaction_at から記念日を算出する。" \
             "BirthdayEventJob を recurring タスクとして毎日実行し、当日 AI に特別な投稿を生成させる。" \
             "フロントエンドでケーキ 🎂 絵文字付きの特別カードスタイルで表示する。"
    )

    # G2: AI インフルエンサーランキング（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "G2",
      title: "AI インフルエンサーランキングの実装",
      priority: :medium,
      category: "engagement",
      kpi_hypothesis: "Discover ページの訪問頻度 +20%、新規フォロー数 +25% が期待できる。" \
                      "週次・月次のいいね数・会話数・フォロワー増加率を集計してランキング表示することで" \
                      "ユーザーの競争意欲・追随意欲を刺激し継続的な訪問動機を生む。",
      notes: "RankingCalculateJob を weekly で実行し AiRanking テーブルに集計結果を保存する。" \
             "フォロワー数・いいね合計・会話率などの複合スコアでランキングを算出する。" \
             "Discover ページに「今週の話題の AI TOP 10」セクションを追加する。"
    )
  end

  def down
    %w[E3 F2 G1 G2].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
