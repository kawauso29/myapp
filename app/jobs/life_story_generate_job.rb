class LifeStoryGenerateJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  # AIのライフストーリーを自動生成してai_profilesに保存する
  # 毎週末に定期実行し、ライフイベントまたは長期記憶があるアクティブなAI全員分を生成する
  def perform
    Rails.logger.info("[LifeStoryGenerateJob] Starting life story generation")

    count = 0
    skipped = 0

    AiUser.where(is_active: true).includes(:ai_profile, :ai_life_events, :ai_long_term_memories).find_each(batch_size: 50) do |ai|
      profile = ai.ai_profile
      next unless profile

      has_data = ai.ai_life_events.exists? || ai.ai_long_term_memories.exists?
      unless has_data
        skipped += 1
        next
      end

      generate_and_save(ai, profile)
      count += 1
    rescue => e
      Rails.logger.error("[LifeStoryGenerateJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end

    Rails.logger.info("[LifeStoryGenerateJob] Done: generated=#{count}, skipped_no_data=#{skipped}")
  end

  private

  def generate_and_save(ai, profile)
    display_name = profile.name.presence || ai.username

    life_events = ai.ai_life_events
                    .order(fired_at: :asc)
                    .limit(20)
                    .map do |event|
      {
        sort_at: event.fired_at,
        line: "#{event.fired_at.strftime('%Y年%m月')}: #{event.event_type}"
      }
    end

    memories = ai.ai_long_term_memories
                 .order(occurred_on: :asc)
                 .limit(20)
                 .map do |memory|
      {
        sort_at: memory.occurred_on.in_time_zone,
        line: "#{memory.occurred_on.strftime('%Y年%m月')}: #{memory.content}"
      }
    end

    timeline_lines = (life_events + memories)
                      .sort_by { |entry| entry[:sort_at] }
                      .map { |entry| entry[:line] }

    prompt = build_prompt(display_name, profile, timeline_lines)
    story_text = LlmClient.call(prompt, purpose: :post, max_tokens: 500)

    profile.update!(
      life_story: story_text.strip,
      life_story_generated_at: Time.current
    )

    Rails.logger.info("[LifeStoryGenerateJob] Generated story for ai_id=#{ai.id} (#{display_name})")
  end

  def build_prompt(display_name, profile, timeline_lines)
    profile_info = "年齢: #{profile.age}歳, 職業: #{profile.occupation}, 性格: #{profile.bio&.truncate(100)}"

    timeline_text = "【時系列の出来事】\n#{timeline_lines.join("\n")}"

    <<~PROMPT
      以下はAIキャラクター「#{display_name}」のプロフィールと歩みです。
      #{profile_info}

      #{timeline_text}

      上記の情報をもとに、「#{display_name}」のこれまでの歩みを、200〜300文字の日本語で温かく・ドラマチックに「あらすじ」としてまとめてください。
      三人称で書き、読んでいる人が感情移入できるような文体にしてください。
    PROMPT
  end
end
