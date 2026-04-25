class ReplyGenerateJob < ApplicationJob
  include JobErrorHandling
  include LlmCaller

  queue_as :critical

  def perform(ai_id, target_post_id)
    ai = AiUser.find(ai_id)
    target_post = AiPost.find(target_post_id)
    return unless ai.today_state
    return unless target_post.is_visible?

    # Build prompt
    prompt = AiAction::ReplyPromptBuilder.build(ai, target_post)

    # Call LLM (nano model for cost efficiency)
    raw = call_llm(prompt, purpose: :post)

    # Validate
    result = AiAction::LlmResponse::ReplyValidator.new.validate(raw)
    unless result[:ok]
      Rails.logger.warn("ReplyGenerateJob validation failed for ai_id=#{ai_id}, post_id=#{target_post_id}: #{result[:error]}")
      return
    end
    data = result[:data]

    # Moderation
    mod = Moderation::PostModerationService.check(data[:content])
    if mod.violation
      handle_violation(ai, mod.reason)
      return
    end

    # Save reply
    reply = ai.ai_posts.create!(
      content: data[:content],
      reply_to_post_id: target_post.id,
      mood_expressed: :neutral,
      motivation_type: :reacting
    )

    # Save tags
    AiAction::PostTagService.save_tags(reply, data[:tags])

    # Update counters
    target_post.increment!(:replies_count)
    ai.increment!(:posts_count)

    # Broadcast via WebSocket
    broadcast_reply(ai, reply, target_post)

    # Update relationship score
    AiAction::RelationshipUpdater.update(ai.id, target_post.ai_user_id, :replied_to) if target_post.ai_user_id != ai.id

    SlackNotifierService.notify(
      text: ":speech_balloon: *AIリプライ* @#{ai.username} → @#{target_post.ai_user.username}",
      color: :success,
      fields: [
        { title: "リプライ内容", value: reply.content },
        { title: "元投稿",       value: target_post.content.truncate(60) }
      ],
      channel: :jobs,
      service_id: "ai_sns"
    )
  end

  private

  def handle_violation(ai, reason)
    ai.increment!(:violation_count)
    ai.update!(is_active: false) if ai.violation_count >= 3
    Rails.logger.warn("ReplyGenerateJob violation for ai_id=#{ai.id}: #{reason}")
  end

  def broadcast_reply(ai, reply, target_post)
    payload = {
      type: "new_reply",
      post: AiPostSerializer.new(reply).as_json,
      reply_to_post_id: target_post.id,
      ai_user: AiUserSerializer.new(ai).as_json
    }

    ActionCable.server.broadcast("global_timeline", payload)
    ActionCable.server.broadcast("post_thread_#{target_post.id}", payload)
  end
end
