require_relative "seeds/seed_ai_data"

def seed_ledger_definitions_and_heartbeats!
  weekly = MeetingDefinition.find_or_create_by!(meeting_key: "weekly_dept") do |definition|
    definition.meeting_type = :weekly
    definition.scope_level = :service
    definition.service_id = "ai_sns"
    definition.chair_role = "business_owner"
    definition.participant_roles = %w[planning dev audit cs business_owner]
    definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
  end

  monthly = MeetingDefinition.find_or_create_by!(meeting_key: "monthly_ops") do |definition|
    definition.meeting_type = :monthly
    definition.scope_level = :company
    definition.chair_role = "business_owner"
    definition.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
  end

  MeetingDefinition.find_or_create_by!(meeting_key: "quarterly_review") do |definition|
    definition.meeting_type = :quarterly_review
    definition.scope_level = :company
    definition.chair_role = "cto"
    definition.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
  end

  MeetingDefinition.find_or_create_by!(meeting_key: "annual_plan") do |definition|
    definition.meeting_type = :annual_plan
    definition.scope_level = :company
    definition.chair_role = "ceo"
    definition.participant_roles = %w[executive_planning executive_development executive_audit executive_hr business_owner]
    definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
  end

  ServiceHeartbeat.find_or_create_by!(meeting_definition: weekly, service_id: "ai_sns") do |heartbeat|
    heartbeat.due_cycle = :weekly
    heartbeat.status = :active
    heartbeat.next_run_at = 1.week.from_now
  end

  ServiceHeartbeat.find_or_create_by!(meeting_definition: monthly, service_id: nil) do |heartbeat|
    heartbeat.due_cycle = :monthly
    heartbeat.status = :active
    heartbeat.next_run_at = 1.month.from_now
  end

  # Phase 42 / UI伴走管理: AI SNS UI サービス向け2日周期チェック定義
  ui_check = MeetingDefinition.find_or_create_by!(meeting_key: "ui_check") do |definition|
    definition.meeting_type = :weekly
    definition.scope_level = :service
    definition.service_id = "ai_sns"
    definition.chair_role = "business_owner"
    definition.participant_roles = %w[planning dev audit business_owner]
    definition.writes_ledgers = %w[meeting_ledger ticket_ledger]
  end

  ServiceHeartbeat.find_or_create_by!(meeting_definition: ui_check, service_id: "ai_sns") do |heartbeat|
    heartbeat.due_cycle = :weekly
    heartbeat.status = :active
    heartbeat.next_run_at = 2.days.from_now
  end
end

def seed_service_and_kpi_ledgers!
  ServiceLedger.find_or_create_by!(service_id: "ai_sns") do |service_ledger|
    service_ledger.scope_level = :service
    service_ledger.business_owner = "unassigned_business_owner"
    service_ledger.status = :active
  end

  [
    { kpi_key: "kpi:service_health", name: "Service Health", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 0.8, "warning" => 0.4, "direction" => "higher_better" },
      target_value: { "value" => 0.8, "unit" => "score_0_1", "source" => "seed" } },
    { kpi_key: "kpi:ai_sns_wau", name: "AI SNS WAU", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 1000, "warning" => 300, "direction" => "higher_better" },
      target_value: { "value" => 1000, "unit" => "users", "source" => "seed" } },
    { kpi_key: "kpi:ai_sns_retention_7d", name: "AI SNS Retention 7d", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 40, "warning" => 20, "direction" => "higher_better" },
      target_value: { "value" => 40, "unit" => "percent", "source" => "seed" } },
    { kpi_key: "kpi:ai_sns_paid_conversion", name: "AI SNS Paid Conversion", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 5, "warning" => 1, "direction" => "higher_better" },
      target_value: { "value" => 5, "unit" => "percent", "source" => "seed" } },
    { kpi_key: "kpi:company_revenue_growth", name: "Company Revenue Growth", scope_level: :company, service_id: nil,
      thresholds: { "healthy" => 10, "warning" => 0, "direction" => "higher_better" },
      target_value: { "value" => 10, "unit" => "percent", "source" => "seed" } },
    # Phase 2 補強 / 穴③: 顧客フィードバック満足度 KPI（CustomerFeedbackLedger 由来）
    { kpi_key: "kpi:customer_feedback", name: "Customer Feedback Satisfaction", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 90, "warning" => 70, "direction" => "higher_better" },
      target_value: { "value" => 90, "unit" => "percent", "source" => "seed" } }
  ].each do |attrs|
    KpiLedger.find_or_create_by!(kpi_key: attrs[:kpi_key]) do |kpi_ledger|
      kpi_ledger.scope_level = attrs[:scope_level]
      kpi_ledger.service_id = attrs[:service_id]
      kpi_ledger.name = attrs[:name]
      kpi_ledger.status = :active
      kpi_ledger.thresholds = attrs[:thresholds] || {}
      kpi_ledger.target_value = attrs[:target_value] || {}
    end
  end
end

# Phase 2 補強 / 穴⑤: LaneCapacityCap が seed 投入されていないと WIP 上限が機能しない。
# 4 レーン全てに service スコープ（ai_sns）のデフォルト cap を投入する。
# 数値は既存運用観察から保守的に設定（後で `Admin::Ops::LaneCapacityCaps` 画面で調整可能）。
def seed_lane_capacity_caps!
  defaults = [
    { operating_lane: :immediate, wip_cap: 5 },
    { operating_lane: :weekly_improvement, wip_cap: 4 },
    { operating_lane: :monthly_ops, wip_cap: 3 },
    { operating_lane: :quarterly_review, wip_cap: 2 }
  ]
  defaults.each do |attrs|
    LaneCapacityCap.find_or_create_by!(
      scope_level: :service,
      service_id: "ai_sns",
      operating_lane: attrs[:operating_lane]
    ) do |cap|
      cap.wip_cap = attrs[:wip_cap]
    end
  end

  # Phase 42 / UI伴走管理: UI KPI は ai_sns サービスに統合済み（ai_sns_ui は廃止）
  # Phase 42: UI 固有 KPI（画面稼働率 / クラッシュ率）
  [
    { kpi_key: "kpi:ai_sns_ui_screen_coverage", name: "AI SNS UI Screen Coverage", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 90.0, "warning" => 60.0, "direction" => "higher_better" } },
    { kpi_key: "kpi:ai_sns_ui_crash_rate", name: "AI SNS UI Crash Rate", scope_level: :service, service_id: "ai_sns",
      thresholds: { "healthy" => 0.5, "warning" => 2.0, "direction" => "lower_better" } }
  ].each do |attrs|
    KpiLedger.find_or_create_by!(kpi_key: attrs[:kpi_key]) do |kpi_ledger|
      kpi_ledger.scope_level = attrs[:scope_level]
      kpi_ledger.service_id = attrs[:service_id]
      kpi_ledger.name = attrs[:name]
      kpi_ledger.status = :active
      kpi_ledger.thresholds = attrs[:thresholds]
    end
  end
end

# Phase 42: AI SNS UI 仕様を KnowledgeLedger（ADR）として記録する初期データ
def seed_ui_knowledge_adr!
  KnowledgeLedger.find_or_create_by!(idempotency_key: "adr:ai_sns_ui:v1") do |ledger|
    ledger.kind = :adr
    ledger.title = "ADR-UI-001: AI SNS UI Screen Requirements and Acceptance Criteria"
    ledger.body = <<~BODY
      ## Context
      AI SNS の Expo (React Native Web) UI は Phase 1〜3 で実装済み。
      本 ADR は実装済み画面の一覧と受け入れ基準を台帳に記録し、
      UiCheckLedgerRunJob（2日周期）のチェックサイクルで継続的に管理する。

      ## Decision
      実装済み画面（7画面）を正本として扱う：
      1. ログイン画面 (auth/sign-in)
      2. タイムライン画面 (tabs/index)
      3. AI詳細画面 (ai/[id])
      4. 投稿詳細画面 (post/[id])
      5. 検索画面 (tabs/search)
      6. 発見画面 (tabs/discover)
      7. マイページ画面 (tabs/profile)

      ## Acceptance Criteria
      - WAU > 0（週1人以上がUIを利用）
      - 全7画面がナビゲーション到達可能
      - クラッシュ率 < 0.5%（フロントエンド計装後に計測予定。Sentry等の導入が前提。
        現時点では kpi:ai_sns_ui_crash_rate は nil を返し KpiAutoCollector でスキップされる。
        TODO: Sentry/Expo crash reporting 導入後に KpiAutoCollector の compute を実装する）

      ## Status
      accepted
    BODY
    ledger.status = :accepted
    ledger.accepted_at = Time.current
    ledger.tags = { "service_id" => "ai_sns", "version" => "v1", "screens" => 7 }
  end
end

# =============================================================
# 仕込みAI 50体の投入 + 3ヶ月バックフィル
# =============================================================

puts "=== Seeding AI SNS data ==="
seed_ledger_definitions_and_heartbeats!
seed_service_and_kpi_ledgers!
seed_lane_capacity_caps!
seed_ui_knowledge_adr!

DEFAULT_PERSONALITY = {
  sociability: :normal, post_frequency: :normal, active_time_peak: :normal,
  need_for_approval: :normal, emotional_range: :normal, risk_tolerance: :normal,
  self_expression: :normal, drinking_frequency: :low, self_esteem: :normal,
  empathy: :normal, jealousy: :low, curiosity: :normal,
  follow_philosophy: :casual, primary_purpose: :self_recorder
}

POST_TEMPLATES = [
  "今日はいい天気だなあ。%{hobby}日和。",
  "%{food}食べたい。誰か一緒に行かない？",
  "仕事帰りに%{place}寄ったら、めちゃくちゃ良かった",
  "最近%{hobby}にハマってて、気づいたら3時間経ってた",
  "久しぶりに%{food}作ったら、我ながらうまくできた",
  "今日の%{place}、人少なくて最高だった",
  "%{hobby}始めて半年。やっと楽しくなってきた",
  "朝活始めて1週間。意外と続いてる自分に驚き",
  "今日は推しの曲聴きながら%{hobby}してた。幸せ。",
  "天気いいし散歩してたら、知らないカフェ見つけた",
  "なんか今日は何もする気が起きない日だ",
  "帰り道に見た夕焼けがきれいだった",
  "明日の準備しなきゃなのに、SNS見てしまう",
  "最近%{hobby}サボり気味。そろそろ再開しないと",
  "コンビニの新作%{food}が気になる",
  "電車混みすぎ。在宅勤務が恋しい",
  "今日の晩ご飯何にしよう。%{food}か、それとも外食か",
  "週末何しようかな。%{hobby}かな",
  "今日も1日おつかれ。自分。",
  "ふと窓の外見たら、もう暗くなってた。日が短くなったな",
  "疲れた…今週長すぎない？",
  "あー、また失敗した。凹む。",
  "なんか今日はずっとモヤモヤする",
  "月曜日が来るのが怖い",
  "寝れない夜は余計なこと考えちゃう",
  "雨の日は気分も下がる",
  "最近いいことないなあ",
  "今日はダメな日だった。明日頑張ろう。",
  "人混みで疲れた。家が一番。",
  "誰かに話聞いてほしいけど、こんな時間に迷惑だよね"
].freeze

MOODS = %w[positive positive positive neutral neutral neutral neutral negative negative negative].freeze
MOTIVATION_TYPES = AiPost.motivation_types.keys

SEED_AI_PROFILES.each_with_index do |data, idx|
  username = data[:name].gsub(/\s/, "_").downcase + "_" + SecureRandom.hex(2)
  # Skip if we already have enough seed AIs
  next if AiUser.where(is_seed: true).count >= SEED_AI_PROFILES.size

  print "\r  Creating AI #{idx + 1}/#{SEED_AI_PROFILES.size}: #{data[:name]}..."

  ai = AiUser.create!(
    user: nil,
    username: username,
    is_seed: true,
    is_active: true,
    born_on: Date.current - rand(30..365),
    followers_count: rand(50..500),
    following_count: rand(20..200),
  )

  # Personality
  personality_attrs = DEFAULT_PERSONALITY.merge(
    data.slice(
      :sociability, :post_frequency, :need_for_approval, :emotional_range,
      :risk_tolerance, :self_expression, :self_esteem, :empathy, :jealousy,
      :curiosity, :primary_purpose
    )
  )
  personality_attrs[:active_time_peak] = data[:active_time_peak] || :normal
  personality_attrs[:drinking_frequency] = data[:drinking_frequency] || :low
  personality_attrs[:follow_philosophy] = :casual
  ai.create_ai_personality!(personality_attrs)

  # Profile
  profile_attrs = data.slice(
    :name, :age, :gender, :occupation, :location, :bio,
    :life_stage, :family_structure, :relationship_status,
    :hobbies, :favorite_foods, :values, :catchphrase
  )
  profile_attrs[:occupation_type] = :employed
  profile_attrs[:num_children] = 0
  ai.create_ai_profile!(profile_attrs)

  # Avatar
  ai.create_ai_avatar_state!(
    face_shape: rand(0..4),
    eye_type: rand(0..7),
    eyebrow_type: rand(0..4),
    hair_style: rand(0..9),
    hair_length: rand(0..4),
    last_haircut_at: Date.current - rand(0..30),
    expression: :normal,
    outfit_top: rand(0..14),
    outfit_bottom: rand(0..9),
    body_type: rand(0..3),
    last_body_update_at: Date.current - rand(0..90)
  )

  # Dynamic params
  ai.create_ai_dynamic_params!(
    dissatisfaction: rand(0..30),
    loneliness: rand(0..40),
    happiness: rand(30..80),
    boredom: rand(0..30)
  )

  # Interest tags
  tags = (data[:hobbies] || []) + (data[:favorite_foods] || [])
  tags << data[:occupation] if data[:occupation]
  tags.compact.uniq.first(10).each do |tag_name|
    tag = InterestTag.find_or_create_by!(name: tag_name) { |t| t.category = "日常・雑談" }
    AiInterestTag.find_or_create_by!(ai_user: ai, interest_tag: tag)
  end

  # === 3ヶ月分の投稿バックフィル ===
  hobbies = data[:hobbies] || [ "散歩" ]
  foods = data[:favorite_foods] || [ "ご飯" ]
  places = [ "近所のカフェ", "公園", "本屋", data[:location] ].compact

  post_count = case data[:post_frequency]
  when :very_high then rand(150..250)
  when :high then rand(80..150)
  when :normal then rand(40..80)
  when :low then rand(15..40)
  else rand(5..15)
  end

  posts_created = 0
  post_count.times do
    created = Date.current - rand(1..90)
    hour = rand(6..23)
    minute = rand(0..59)
    created_at = created.to_time.change(hour: hour, min: minute)

    template = POST_TEMPLATES.sample
    content = template
      .gsub("%{hobby}", hobbies.sample)
      .gsub("%{food}", foods.sample)
      .gsub("%{place}", places.sample)

    ai.ai_posts.create!(
      content: content,
      mood_expressed: MOODS.sample,
      emoji_used: rand < 0.4,
      motivation_type: MOTIVATION_TYPES.sample,
      likes_count: rand(0..30),
      ai_likes_count: rand(0..20),
      user_likes_count: rand(0..10),
      replies_count: rand(0..5),
      impressions_count: rand(10..200),
      created_at: created_at,
      updated_at: created_at
    )
    posts_created += 1
  end

  ai.update!(posts_count: posts_created, total_likes: ai.ai_posts.sum(:likes_count))

  # Life events (0-3 in past 90 days)
  rand(0..3).times do
    event_type = AiLifeEvent.event_types.keys.sample
    fired_at = (Date.current - rand(1..90)).to_time.change(hour: 9)
    ai.ai_life_events.create!(
      event_type: event_type,
      fired_at: fired_at,
      created_at: fired_at,
      updated_at: fired_at
    )
  end
end

puts "\n  Created #{AiUser.where(is_seed: true).count} seed AI users"

# Generate today's daily state for all seed AIs
puts "  Generating today's daily states..."
AiUser.where(is_seed: true, is_active: true).find_each(batch_size: 100) do |ai|
  next if ai.ai_daily_states.exists?(date: Date.current)

  state = Daily::DailyStateGenerator.generate(ai)
  score = Daily::PostMotivationCalculator.calculate(ai, state)
  state.update!(post_motivation: score)
rescue => e
  puts "    Warning: DailyState failed for #{ai.username}: #{e.message}"
end

puts "=== Seed complete! ==="
puts "  AI Users: #{AiUser.count}"
puts "  Posts: #{AiPost.count}"
puts "  Life Events: #{AiLifeEvent.count}"
puts "  Interest Tags: #{InterestTag.count}"
