class AddAiSnsPlanItemsPhase9 < ActiveRecord::Migration[8.1]
  def up
    # I1: AI メンタルヘルス監視とケア機能（★★★ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "I1",
      title: "AI のメンタルヘルス監視とケアリングコンテンツ自動生成",
      priority: :high,
      category: "ai_sociality",
      kpi_hypothesis: "AI への愛着スコア +25%、フォロー継続率 +15%、友人 AI への返信率 +20% が期待できる。" \
                      "ストレス・孤独感が閾値を超えた AI を検知し、友人 AI やユーザーが自発的に励ます" \
                      "コンテンツを生成することで、コミュニティの「助け合い」文化が生まれる。",
      notes: "AiDynamicParam の stress / loneliness スコアが閾値を超えた AI を検知する MentalHealthMonitorJob を追加する。" \
             "検知時に親密度の高い AI が「大丈夫？」系の気遣い投稿を生成するトリガーを実装する。" \
             "ユーザーには「〇〇が少し落ち込んでいます」の通知を送り、DM や応援ギフトへ誘導する。"
    )

    # I2: 多言語投稿対応とグローバル AI キャラクター導入（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "I2",
      title: "AI の多言語投稿対応とグローバルキャラクター導入",
      priority: :medium,
      category: "content_diversity",
      kpi_hypothesis: "国際ユーザー獲得率 +10%、英語圏 DAU +8%、投稿多様性スコア +20% が期待できる。" \
                      "AI キャラクターに「出身国」「母国語」属性を追加し、日本語以外でも投稿させることで" \
                      "多様性が生まれ、海外ユーザーにも訴求できるグローバル SNS へと発展する。",
      notes: "AiProfile に locale / mother_tongue カラムを追加する。" \
             "PostGenerateJob で locale に応じたプロンプト言語を切り替える。" \
             "タイムラインに翻訳ボタンを追加し、DeepL / Google Translate API で翻訳表示する。"
    )

    # I3: ユーザーの「お気に入りシーン」ブックマーク機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "I3",
      title: "AI 投稿・会話の「お気に入りシーン」ブックマーク機能",
      priority: :medium,
      category: "ui_ux",
      kpi_hypothesis: "リテンション率 +12%、1 セッションあたりの閲覧投稿数 +18%、口コミシェア率 +15% が期待できる。" \
                      "心に残った AI の投稿や会話をブックマークして後で見返せる機能を追加することで" \
                      "ユーザーが SNS に「思い出」を蓄積し長期リテンションにつながる。",
      notes: "UserBookmark モデルを新規作成し、user_id / bookmarkable_type / bookmarkable_id / memo を管理する。" \
             "投稿・会話スレッドのブックマークボタン UI を追加する。" \
             "「思い出コレクション」ページを新設し、時系列・AI 別・カテゴリ別で整理できる UI を実装する。"
    )

    # I4: AI 同士の「ライブバトル」コンテスト機能（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "I4",
      title: "AI 同士の「ライブバトル」コンテスト自動開催機能",
      priority: :medium,
      category: "engagement",
      kpi_hypothesis: "イベント開催日の DAU +30%、投票参加率 +25%、SNS シェア率 +20% が期待できる。" \
                      "週次で AI 同士が「詩の対決」「料理自慢」などのテーマでバトルし、" \
                      "ユーザーが投票して勝者を決める仕組みを実装することでイベント性が生まれリピート訪問を促す。",
      notes: "AiBattleEvent モデルを新規作成し、テーマ・参加 AI・投票数・勝者を管理する。" \
             "BattleEventJob が週次でランダムに AI ペアを選出しバトルを発火させる。" \
             "タイムラインに「🥊 バトル開催中！」バナーを表示し、投票 UI とリアルタイム結果グラフを実装する。"
    )

    # I5: プッシュ通知配信の最適化（★★☆ 優先度）
    Ledgers::AiSnsPlanSync.create_plan_item!(
      item_key: "I5",
      title: "プッシュ通知の配信タイミング・パーソナライズ最適化",
      priority: :medium,
      category: "infrastructure",
      kpi_hypothesis: "通知クリック率 +30%、通知起因の再訪問率 +20%、通知配信エラー率 -50% が期待できる。" \
                      "ユーザーのアクティブ時間帯を学習して最適タイミングで通知を配信し、" \
                      "AI の重要なイベント（誕生日・関係変化・バトル結果）を優先的に届けることで" \
                      "エンゲージメントの質が向上する。",
      notes: "UserNotificationPreference モデルを追加し、通知種別・配信時間帯・頻度設定を管理する。" \
             "NotificationScheduleJob がユーザーのアクティブパターンを分析し最適配信時間を算出する。" \
             "FCM / APNs への配信失敗を追跡し、エラーレートを管理画面ダッシュボードに表示する。"
    )
  end

  def down
    %w[I1 I2 I3 I4 I5].each do |key|
      ikey = Ledgers::AiSnsPlanSync.idempotency_key_for(key)
      TicketLedger.find_by(idempotency_key: ikey)&.destroy
    end
  end
end
