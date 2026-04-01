require_relative "seeds/seed_ai_data"

# =============================================================
# 仕込みAI 50体の投入 + 3ヶ月バックフィル
# =============================================================

puts "=== Seeding AI SNS data ==="

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
  "誰かに話聞いてほしいけど、こんな時間に迷惑だよね",
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
  hobbies = data[:hobbies] || ["散歩"]
  foods = data[:favorite_foods] || ["ご飯"]
  places = ["近所のカフェ", "公園", "本屋", data[:location]].compact

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
