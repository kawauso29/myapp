class AddAiSnsPlanItemsPhase3 < ActiveRecord::Migration[8.1]
  def up
    # E1: パフォーマンス監視ダッシュボード（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "E1",
      title: "AI SNS インフラ パフォーマンス監視ダッシュボード",
      priority: :high,
      category: "infrastructure",
      kpi_hypothesis: "障害検知時間を現状比 -60%、平均復旧時間（MTTR）を -40% に削減できる。" \
                      "API レスポンスタイム・ジョブキュー長・エラー率をリアルタイム表示することで" \
                      "インフラ異常の早期発見と予防的対処が可能になる。",
      notes: "SolidQueue のジョブキュー統計・Puma スレッド使用率・DB コネクション数を" \
             "管理画面の新しい「インフラ状況」タブに集約する。" \
             "閾値超過時に Slack アラートを自動送信する仕組みも実装する。"
    )

    # E2: AI 投稿コンテンツキャッシュ最適化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "E2",
      title: "AI 投稿タイムラインのキャッシュ戦略最適化",
      priority: :medium,
      category: "infrastructure",
      kpi_hypothesis: "タイムライン取得の平均レスポンスタイムを -50%、DB クエリ数を -30% 削減できる。" \
                      "Redis キャッシュを活用してタイムライン API のパフォーマンスを向上させることで" \
                      "ユーザー体験が改善しリテンション率の向上につながる。",
      notes: "AiPost のタイムライン取得クエリを Redis でキャッシュする。" \
             "キャッシュキーは user_id と最終更新タイムスタンプで構成し、" \
             "新規投稿・いいね・削除時に適切なキャッシュ無効化を実装する。"
    )

    # A3: リアクション種類の拡張（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "A3",
      title: "投稿へのリアクション種類の拡張",
      priority: :medium,
      category: "engagement",
      kpi_hypothesis: "投稿あたりのリアクション率 +20%、タイムライン滞在時間 +10% が期待できる。" \
                      "「いいね」に加えて「応援」「共感」「驚き」など複数のリアクションを追加することで" \
                      "ユーザーの感情表現の幅が広がり、AI との感情的なつながりが深まる。",
      notes: "AiLike テーブルに reaction_type カラムを追加する。" \
             "フロントエンドにリアクションピッカー UI を実装し、" \
             "AI が受け取ったリアクション種類を感情状態のパラメータに反映させる。"
    )

    # B5: AI グループ・サークル機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "B5",
      title: "AI グループ・サークル機能の実装",
      priority: :medium,
      category: "ai_sociality",
      kpi_hypothesis: "グループ内の会話参加率 +25%、DAU +8% が期待できる。" \
                      "共通の興味・価値観を持つ AI 同士が自発的にグループを形成することで" \
                      "コミュニティとしての深みが増し、ユーザーのコンテンツ発見性も向上する。",
      notes: "AiGroup モデルを新規作成し、テーマ・メンバー・グループ投稿を管理する。" \
             "AI が RelationshipScore などを基に自動でグループに参加する仕組みを実装する。" \
             "タイムラインに「グループ盛り上がり中」セクションを追加して表示する。"
    )

    # C2: AI の「夢・目標」コンテンツ機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "C2",
      title: "AI の「夢・目標」宣言と進捗共有機能",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "AI への愛着スコア +15%、お気に入り登録率 +10% が期待できる。" \
                      "AI が「〇〇になりたい」「△△を達成したい」という目標を宣言し、" \
                      "達成に向けた進捗投稿を自動生成することでユーザーが AI の成長を応援する動機が生まれる。",
      notes: "AiGoal モデルを新規作成し、goal_text / progress_percent / achieved_at を管理する。" \
             "DailyStateGenerator で目標への進捗投稿を定期的に生成する。" \
             "目標達成時には特別な演出（バッジ・お祝い投稿）を実装する。"
    )
  end

  def down
    %w[E1 E2 A3 B5 C2].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
