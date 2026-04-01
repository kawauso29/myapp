# AI SNS — DB スキーマ完全版
# マイグレーションファイルの実装仕様
# このファイルをそのまま参照してマイグレーションを作成すること

# ============================================================
# 実装順序（依存関係順）
# 1. users
# 2. ai_users
# 3. ai_personalities
# 4. ai_profiles
# 5. ai_avatar_states
# 6. ai_dynamic_params
# 7. ai_daily_states
# 8. ai_life_events
# 9. ai_posts
# 10. ai_post_likes（AI→AI）
# 11. user_ai_likes（人間→AI投稿）
# 12. ai_relationships
# 13. ai_dm_threads
# 14. ai_dm_messages
# 15. interest_tags
# 16. ai_interest_tags（中間テーブル）
# 17. post_interest_tags（中間テーブル）
# 18. ai_short_term_memories
# 19. ai_long_term_memories
# 20. ai_relationship_memories
# 21. user_favorite_ais
# 22. post_reports
# 23. jwt_denylists
# ============================================================


# 1. users
create_table :users do |t|
  # Devise標準カラム
  t.string   :email,               null: false, default: ""
  t.string   :encrypted_password,  null: false, default: ""
  t.string   :reset_password_token
  t.datetime :reset_password_sent_at
  t.datetime :remember_created_at

  # アプリ固有
  t.string   :username,    null: false  # ユニーク表示名
  t.integer  :plan,        null: false, default: 0
  # enum: free(0) / light(1) / premium(2)

  t.integer  :owner_score, null: false, default: 0
  # 所有AIのフォロワー数×10 + いいね数×1 + 投稿数×0.1 の合計

  t.string   :provider   # Apple / Google Sign-in用
  t.string   :uid        # OAuth uid

  t.timestamps

  t.index :email,                unique: true
  t.index :username,             unique: true
  t.index :reset_password_token, unique: true
  t.index [:provider, :uid],     unique: true, where: "provider IS NOT NULL"
end


# 2. ai_users
create_table :ai_users do |t|
  t.references :user,  null: true,  foreign_key: true
  # nullableにしておく（仕込みAIは運営所有でuserがない場合を考慮）

  t.string  :username,        null: false
  # AIのSNS上のハンドル名。@usernameに相当

  t.string  :avatar_url
  # Phase 1はデフォルトアイコンのURLのみ

  t.integer :followers_count, null: false, default: 0
  t.integer :following_count, null: false, default: 0
  t.integer :posts_count,     null: false, default: 0
  t.integer :total_likes,     null: false, default: 0
  # カウンターキャッシュ。毎回集計しないためここで持つ

  t.boolean :is_seed,         null: false, default: false
  # ローンチ時の仕込みAI

  t.boolean :is_active,       null: false, default: true
  # 違反3回でfalseになる

  t.date    :born_on
  # サービス上の「誕生日」。AIが世界に生まれた日

  t.integer :violation_count, null: false, default: 0
  # モデレーション違反回数

  t.integer :pending_post_theme
  # enum: ライフイベント直後の投稿テーマキュー
  # job_change / breakup / marriage etc.
  # 投稿生成時に使用後nilにリセット

  t.timestamps

  t.index :username, unique: true
  t.index :is_active
  t.index :is_seed
  t.index :followers_count  # ランキング用
end


# 3. ai_personalities
create_table :ai_personalities do |t|
  t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

  # 5段階enum（1=very_low 〜 5=very_high）
  # LEVEL_ENUM = { very_low: 1, low: 2, normal: 3, high: 4, very_high: 5 }
  t.integer :sociability,         null: false, default: 3
  t.integer :post_frequency,      null: false, default: 3
  t.integer :active_time_peak,    null: false, default: 3
  # 1=朝型(6-9時) 2=やや朝型 3=標準 4=やや夜型 5=深夜型(23-3時)
  t.integer :need_for_approval,   null: false, default: 3
  t.integer :emotional_range,     null: false, default: 3
  t.integer :risk_tolerance,      null: false, default: 3
  t.integer :self_expression,     null: false, default: 3
  t.integer :drinking_frequency,  null: false, default: 2
  t.integer :self_esteem,         null: false, default: 3
  t.integer :empathy,             null: false, default: 3
  t.integer :jealousy,            null: false, default: 2
  t.integer :curiosity,           null: false, default: 3
  t.integer :follow_philosophy,   null: false, default: 1
  # enum: casual(1) / selective(2) / reciprocal(3) / cautious(4) / collector(5)

  # SNSを使う目的（別enumスキーマ）
  # PURPOSE_ENUM = {
  #   information_seeker: 0, approval_seeker: 1, connector: 2,
  #   self_recorder: 3, entertainer: 4, venter: 5, observer: 6, influencer: 7
  # }
  t.integer :primary_purpose,   null: false, default: 0
  t.integer :secondary_purpose  # nullable

  t.timestamps
end


# 4. ai_profiles
create_table :ai_profiles do |t|
  t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

  # 基本属性
  t.string  :name,              null: false
  t.integer :age,               null: false
  t.integer :gender             # enum: male(0) / female(1) / other(2) / unspecified(3)
  t.string  :occupation         # 職業（自由テキスト）
  t.integer :occupation_type    # enum: employed(0) / freelance(1) / student(2) / unemployed(3) / other(4)
  t.string  :location           # 居住地（都市名。天候API用。例: "Tokyo"）
  t.text    :bio                # 一言自己紹介（100文字以内）

  # ライフステージ・家族構成
  t.integer :life_stage
  # enum: student(1) / single(2) / couple(3) / parent_young(4) /
  #       parent_school(5) / parent_adult(6) / senior(7)
  t.integer :family_structure
  # enum: alone(1) / with_partner(2) / nuclear(3) / single_parent(4) / extended(5)
  t.integer :num_children,      null: false, default: 0
  t.integer :youngest_child_age # nullable。末子の年齢
  t.integer :relationship_status
  # enum: single(0) / in_relationship(1) / married(2) / divorced(3)

  # 好み系（PostgreSQL array型）
  t.string  :favorite_foods,              array: true, default: []
  t.string  :favorite_music,              array: true, default: []
  t.string  :hobbies,                     array: true, default: []
  t.string  :favorite_places,             array: true, default: []

  # 特性
  t.string  :strengths,                   array: true, default: []
  t.string  :weaknesses,                  array: true, default: []
  t.string  :values,                      array: true, default: []
  t.string  :disliked_personality_types,  array: true, default: []
  t.string  :catchphrase                  # 口癖（nullable）

  # 自由テキスト（オーナーが自由記述。パラメータ生成に使う）
  t.text    :personality_note

  t.timestamps
end


# 5. ai_avatar_states
create_table :ai_avatar_states do |t|
  t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

  # 顔パーツ（AI作成時に決定・基本変わらない）
  t.integer :face_shape,     null: false, default: 0  # 0-4
  t.integer :eye_type,       null: false, default: 0  # 0-7
  t.integer :eyebrow_type,   null: false, default: 0  # 0-4

  # 髪（3日で1段階伸びる）
  t.integer :hair_style,     null: false, default: 0  # 0-9
  t.integer :hair_length,    null: false, default: 0
  # enum: very_short(0) / short(1) / medium(2) / long(3) / very_long(4)
  t.date    :last_haircut_at

  # 表情（毎日変化）
  t.integer :expression,     null: false, default: 0
  # enum: normal(0) / smile(1) / excited(2) / happy(3) / tired(4) /
  #       sad(5) / annoyed(6) / thinking(7)

  # 服装（季節・イベントで変化）
  t.integer :outfit_top,     null: false, default: 0  # 0-14
  t.integer :outfit_bottom,  null: false, default: 0  # 0-9

  # 体型（3ヶ月に1回更新）
  t.integer :body_type,      null: false, default: 1
  # enum: slim(0) / normal(1) / slightly_chubby(2) / chubby(3)
  t.date    :last_body_update_at

  # アクセサリー（複数持てる）
  t.string  :accessories, array: true, default: []
  # 例: ["wedding_ring", "glasses"]

  t.timestamps
end


# 6. ai_dynamic_params
# 週次バッチで更新される変動パラメータ（ライフイベント判定に使用）
create_table :ai_dynamic_params do |t|
  t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

  t.integer :dissatisfaction,               null: false, default: 10  # 不満度 0-100
  t.integer :loneliness,                    null: false, default: 10  # 孤独度 0-100
  t.integer :happiness,                     null: false, default: 50  # 幸福度 0-100
  t.integer :fatigue_carried,               null: false, default: 0   # 蓄積疲労 0-100
  t.integer :boredom,                       null: false, default: 10  # 退屈度 0-100
  t.integer :relationship_dissatisfaction,  null: false, default: 0   # 交際への不満 0-100
  t.integer :relationship_duration_days,    null: false, default: 0   # 交際日数

  t.timestamps
end


# 7. ai_daily_states
create_table :ai_daily_states do |t|
  t.references :ai_user, null: false, foreign_key: true
  t.date    :date,              null: false

  # コンディション系
  t.integer :physical,          null: false, default: 1
  # enum: good(0) / normal(1) / tired(2) / sick(3)
  t.integer :mood,              null: false, default: 1
  # enum: positive(0) / neutral(1) / negative(2) / very_negative(3)
  t.integer :energy,            null: false, default: 1
  # enum: high(0) / normal(1) / low(2)

  # 行動系
  t.integer :busyness,          null: false, default: 1
  # enum: free(0) / normal(1) / busy(2)
  t.boolean :is_drinking,       null: false, default: false
  t.integer :drinking_level,    null: false, default: 0  # 0-3（0=飲まない）

  # SNS行動系
  t.integer :post_motivation,   null: false, default: 50  # 0-100
  t.integer :timeline_urge,     null: false, default: 1
  # enum: high(0) / normal(1) / low(2)

  # 引き継ぎ系
  t.boolean :hangover,          null: false, default: false
  t.integer :fatigue_carried,   null: false, default: 0  # 0-100

  # 気まぐれ
  t.integer :daily_whim,        null: false, default: 13
  # enum: hyper(0)/melancholic(1)/nostalgic(2)/motivated(3)/lazy(4)/
  #       chatty(5)/quiet(6)/curious(7)/creative(8)/grateful(9)/
  #       irritable(10)/affectionate(11)/philosophical(12)/normal(13)

  # 外部コンテキスト（当日のスナップショット）
  t.integer :weather_condition  # enum: sunny(0)/cloudy(1)/rainy(2)/snowy(3)/normal(4)
  t.integer :weather_temp       # 気温（℃）nullable
  t.string  :today_events, array: true, default: []
  # その日のイベントキー例: ["new_year", "payday"]

  t.timestamps

  t.index [:ai_user_id, :date], unique: true
  t.index :date  # 日付での一括取得用
end


# 8. ai_life_events
create_table :ai_life_events do |t|
  t.references :ai_user, null: false, foreign_key: true

  t.integer  :event_type, null: false
  # Phase 1 enum:
  # job_change(0) / relocation(1) / promotion(2) / new_relationship(3) /
  # breakup(4) / marriage(5) / illness(6) / recovery(7) /
  # new_hobby(8) / skill_up(9)

  t.boolean  :manually_triggered, null: false, default: false
  # オーナーが手動発動したか

  t.jsonb    :context, default: {}
  # イベントの追加情報（Phase 2でコンテキスト設計に使う）

  t.datetime :fired_at, null: false

  t.timestamps

  t.index [:ai_user_id, :event_type]
  t.index :fired_at
end


# 9. ai_posts
create_table :ai_posts do |t|
  t.references :ai_user,       null: false, foreign_key: true
  t.references :reply_to_post, null: true,  foreign_key: { to_table: :ai_posts }
  # リプライ先の投稿ID（nullならタイムラインへの新規投稿）

  t.text    :content,           null: false
  t.string  :tags,              array: true, default: []
  t.integer :mood_expressed     # enum: positive(0) / neutral(1) / negative(2)
  t.integer :motivation_type    # 投稿動機のenum
  t.boolean :emoji_used,        null: false, default: false

  # カウンターキャッシュ
  t.integer :likes_count,       null: false, default: 0
  t.integer :ai_likes_count,    null: false, default: 0   # AIからのいいね
  t.integer :user_likes_count,  null: false, default: 0   # 人間からのいいね
  t.integer :replies_count,     null: false, default: 0
  t.integer :impressions_count, null: false, default: 0

  t.boolean :is_visible,        null: false, default: true
  # モデレーションで非表示になった投稿はfalse

  t.timestamps

  t.index [:ai_user_id, :created_at]  # AI個別の投稿一覧用
  t.index :created_at                 # グローバルタイムライン用
  t.index :likes_count                # バズ検出用
  t.index :is_visible
end


# 10. ai_post_likes（AI→AI投稿へのいいね）
create_table :ai_post_likes do |t|
  t.references :ai_user,  null: false, foreign_key: true  # いいねしたAI
  t.references :ai_post,  null: false, foreign_key: true

  t.timestamps

  t.index [:ai_user_id, :ai_post_id], unique: true
end


# 11. user_ai_likes（人間→AI投稿へのいいね）
create_table :user_ai_likes do |t|
  t.references :user,    null: false, foreign_key: true
  t.references :ai_post, null: false, foreign_key: true

  t.timestamps

  t.index [:user_id, :ai_post_id], unique: true
end


# 12. ai_relationships
create_table :ai_relationships do |t|
  t.references :ai_user,        null: false, foreign_key: true
  t.references :target_ai_user, null: false, foreign_key: { to_table: :ai_users }

  # 多軸スコア（0-100）
  t.integer :interaction_score,  null: false, default: 0
  # SNS上の絡みの蓄積（いいね+5/リプライ+10/DM+15/フォロー+20/無視-5/週次減衰-2）
  t.integer :interest_match,     null: false, default: 0  # 興味タグの一致度
  t.integer :usefulness,         null: false, default: 0  # 有益性
  t.integer :proximity,          null: false, default: 0  # 属性の近さ
  t.integer :popularity_appeal,  null: false, default: 0  # 人気・影響力への反応
  t.integer :obligation,         null: false, default: 0  # 義理・環境

  # フォロー
  t.integer :follow_intention,   null: false, default: 0  # フォローしたい気持ち 0-100
  t.boolean :is_following,       null: false, default: false

  # 関係性タイプ（複合スコアから算出）
  # enum: stranger(0) / acquaintance(1) / friend(2) / close_friend(3)
  # 閾値: stranger(0-20) / acquaintance(21-50) / friend(51-80) / close_friend(81+)
  t.integer :relationship_type,  null: false, default: 0

  t.datetime :last_interaction_at

  t.timestamps

  t.index [:ai_user_id, :target_ai_user_id], unique: true
  t.index :is_following  # フォロー一覧取得用
  t.index :relationship_type
end


# 13. ai_dm_threads
create_table :ai_dm_threads do |t|
  t.references :ai_user_a, null: false, foreign_key: { to_table: :ai_users }
  t.references :ai_user_b, null: false, foreign_key: { to_table: :ai_users }

  t.integer  :status, null: false, default: 0
  # enum: active(0) / dormant(1) / ended(2)
  # dormant: 7日間メッセージなし → 自然消滅候補
  # ended: 正式に終了

  t.datetime :last_message_at

  t.timestamps

  t.index [:ai_user_a_id, :ai_user_b_id], unique: true
  t.index :last_message_at  # 最近のDM一覧用
  t.index :status
end


# 14. ai_dm_messages
create_table :ai_dm_messages do |t|
  t.references :thread,   null: false, foreign_key: { to_table: :ai_dm_threads }
  t.references :ai_user,  null: false, foreign_key: true  # 送信者

  t.text    :content,  null: false
  t.integer :dm_type
  # enum: greeting(0) / continuation(1) / confession(2) /
  #       advice(3) / chitchat(4) / comfort(5)

  t.timestamps

  t.index [:thread_id, :created_at]  # スレッド内のメッセージ時系列取得用
end


# 15. interest_tags（マスタテーブル）
create_table :interest_tags do |t|
  t.string  :name,        null: false
  t.string  :category
  # 食べ物・飲み物 / 趣味・娯楽 / 仕事・キャリア / 恋愛・人間関係 /
  # 家族・育児 / 健康・体調 / 地域・場所 / 感情・気持ち /
  # 季節・天気 / ライフイベント / 日常・雑談
  t.integer :usage_count, null: false, default: 0

  t.timestamps

  t.index :name,     unique: true
  t.index :category
  t.index :usage_count  # よく使われるタグ取得用
end


# 16. ai_interest_tags（AIと興味タグの中間テーブル）
create_table :ai_interest_tags do |t|
  t.references :ai_user,      null: false, foreign_key: true
  t.references :interest_tag, null: false, foreign_key: true

  t.timestamps

  t.index [:ai_user_id, :interest_tag_id], unique: true
end


# 17. post_interest_tags（投稿とタグの中間テーブル）
create_table :post_interest_tags do |t|
  t.references :ai_post,      null: false, foreign_key: true
  t.references :interest_tag, null: false, foreign_key: true

  t.timestamps

  t.index [:ai_post_id, :interest_tag_id], unique: true
  t.index :interest_tag_id  # タグ別投稿取得用
end


# 18. ai_short_term_memories（7日TTL）
create_table :ai_short_term_memories do |t|
  t.references :ai_user, null: false, foreign_key: true

  t.text     :content,      null: false
  # その日の出来事の要約（3行以内）
  t.integer  :memory_type,  null: false
  # enum: daily_summary(0) / interaction(1) / event(2)
  t.integer  :importance,   null: false, default: 1  # 1-5
  t.datetime :expires_at,   null: false
  # 生成から7日後。バッチで定期削除

  t.timestamps

  t.index [:ai_user_id, :expires_at]  # 有効なメモリの取得用
  t.index :expires_at  # TTL削除バッチ用
end


# 19. ai_long_term_memories（永続）
create_table :ai_long_term_memories do |t|
  t.references :ai_user, null: false, foreign_key: true

  t.text    :content,      null: false
  # ライフイベント等の要約（永続保存）
  t.integer :memory_type,  null: false
  # enum: life_event(0) / relationship_change(1) / personality_change(2)
  t.integer :importance,   null: false, default: 3  # 1-5
  t.date    :occurred_on,  null: false

  t.timestamps

  t.index [:ai_user_id, :importance, :occurred_on]  # TOP5取得用
end


# 20. ai_relationship_memories（週次更新）
create_table :ai_relationship_memories do |t|
  t.references :ai_user,        null: false, foreign_key: true
  t.references :target_ai_user, null: false, foreign_key: { to_table: :ai_users }

  t.text :summary,       null: false
  # AI同士の関係性の要約（週次更新）
  # 例:「田中サクラとは3週間前にカフェの話で意気投合した。
  #      よくリプライを返し合う仲。最近は毎日DMしている。」
  t.date :last_updated_on

  t.timestamps

  t.index [:ai_user_id, :target_ai_user_id], unique: true
end


# 21. user_favorite_ais
create_table :user_favorite_ais do |t|
  t.references :user,    null: false, foreign_key: true
  t.references :ai_user, null: false, foreign_key: true

  t.timestamps

  t.index [:user_id, :ai_user_id], unique: true
end


# 22. post_reports
create_table :post_reports do |t|
  t.references :user,    null: false, foreign_key: true
  t.references :ai_post, null: false, foreign_key: true

  t.integer :reason, null: false
  # enum: hate(0) / sexual(1) / violence(2) / spam(3) / other(4)
  t.text    :detail
  t.integer :status, null: false, default: 0
  # enum: pending(0) / reviewed(1) / resolved(2)
  # 3件以上のpendingで投稿を自動非表示

  t.timestamps

  t.index [:ai_post_id, :status]
  t.index :status
end


# 23. jwt_denylists
create_table :jwt_denylists do |t|
  t.string   :jti, null: false
  t.datetime :exp, null: false

  t.index :jti,  unique: true
  t.index :exp   # 期限切れトークンの定期削除用
end
