require "cgi"

class PostGenerateJob < ApplicationJob
  include JobErrorHandling
  include LlmCaller

  queue_as :critical

  def perform(ai_id, motivation)
    ai = AiUser.find(ai_id)
    daily_state = ai.today_state
    return unless daily_state

    motivation = motivation.deep_symbolize_keys if motivation.is_a?(Hash)

    # Build prompt
    prompt = AiAction::PostPromptBuilder.build(ai, daily_state, motivation)

    # Call LLM (nano model for cost efficiency)
    raw = call_llm(prompt, purpose: :post)

    # Validate
    result = AiAction::LlmResponse::PostValidator.new(max_length: ai.max_post_length).validate(raw)
    unless result[:ok]
      Rails.logger.warn("PostGenerateJob validation failed for ai_id=#{ai_id}: #{result[:error]}")
      return
    end
    data = result[:data]

    # Moderation
    mod = Moderation::PostModerationService.check(data[:content])
    if mod.violation
      handle_violation(ai, mod.reason)
      return
    end

    # Save post
    post = ai.ai_posts.create!(
      content: data[:content],
      mood_expressed: data[:mood_expressed],
      emoji_used: data[:emoji_used],
      motivation_type: motivation[:primary],
      image_prompt: image_prompt_for(ai, data[:content]),
      image_url: image_url_for(ai, data[:content])
    )

    # Save tags
    AiAction::PostTagService.save_tags(post, data[:tags])

    # Update counter
    ai.increment!(:posts_count)

    # Broadcast via WebSocket
    broadcast_post(ai, post)

    # Push notification to favorited users (failure must not fail the post)
    begin
      Notification::OwnerNotificationService.notify_post(ai, post)
    rescue => e
      Rails.logger.error("PostGenerateJob notify_post failed for ai_id=#{ai.id}: #{e.class}: #{e.message}")
    end

    SlackNotifierService.notify(
      text: ":pencil: *AI投稿* @#{ai.username}",
      color: :success,
      fields: [
        { title: "内容",           value: post.content },
        { title: "モチベーション", value: motivation[:primary].to_s, short: true },
        { title: "気分",           value: post.mood_expressed.to_s, short: true }
      ],
      channel: :jobs
    )
  end

  private

  def handle_violation(ai, reason)
    ai.increment!(:violation_count)
    ai.update!(is_active: false) if ai.violation_count >= 3
    Rails.logger.warn("PostGenerateJob violation for ai_id=#{ai.id}: #{reason}")
  end

  def broadcast_post(ai, post)
    ActionCable.server.broadcast("global_timeline", {
      type: "new_post",
      post: AiPostSerializer.new(post).as_json,
      ai_user: AiUserSerializer.new(ai).as_json
    })
  end

  def image_prompt_for(ai, content)
    return nil unless ai.premium_ai?

    "SNS post illustration, anime-style, #{content.to_s.truncate(120)}"
  end

  def image_url_for(ai, content)
    return nil unless ai.premium_ai?

    prompt = CGI.escape(content.to_s.truncate(120))
    "https://image.pollinations.ai/prompt/#{prompt}"
  end
end
