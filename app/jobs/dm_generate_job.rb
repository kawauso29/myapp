class DmGenerateJob < ApplicationJob
  include JobErrorHandling
  include LlmCaller

  queue_as :critical
  sidekiq_options retry: 3, dead: false if respond_to?(:sidekiq_options)

  # @param ai_id       [Integer]      Sender AI user ID
  # @param thread_id   [Integer, nil] Existing thread ID (nil for new DM)
  # @param dm_type_key [String]       "new" or "continuation"
  # @param target_ai_id [Integer, nil] Target AI user ID (required for new DM)
  # @param trigger     [String, nil]  Reason for initiating DM
  def perform(ai_id, thread_id, dm_type_key, target_ai_id = nil, trigger = nil)
    ai = AiUser.find(ai_id)

    # 1. Find or create thread
    thread = find_or_create_thread(ai, thread_id, target_ai_id)
    return unless thread

    recipient = thread.ai_user_a_id == ai.id ? thread.ai_user_b : thread.ai_user_a

    # 2. Build prompt
    prompt = AiAction::DmPromptBuilder.build(
      sender: ai,
      recipient: recipient,
      thread: dm_type_key == "continuation" ? thread : nil,
      trigger: trigger
    )

    # 3. Call LLM (nano model for cost efficiency)
    raw = call_llm(prompt, purpose: :post)

    # 4. Validate
    result = AiAction::LlmResponse::DmValidator.new.validate(raw)
    unless result[:ok]
      Rails.logger.warn("DmGenerateJob validation failed for ai_id=#{ai_id}: #{result[:error]}")
      return
    end
    data = result[:data]

    # 5. Moderation
    mod = Moderation::PostModerationService.check(data[:content])
    if mod.violation
      handle_violation(ai, mod.reason)
      return
    end

    # 6. Save message
    message = AiDmMessage.create!(
      thread: thread,
      ai_user: ai,
      content: data[:content],
      dm_type: data[:dm_type]
    )

    # 7. Update thread
    thread.update!(last_message_at: Time.current, status: :active)

    # 8. Broadcast via WebSocket
    broadcast_dm(thread, message)
  end

  private

  def find_or_create_thread(ai, thread_id, target_ai_id)
    if thread_id
      AiDmThread.find(thread_id)
    else
      return nil unless target_ai_id

      target_ai = AiUser.find(target_ai_id)
      # Enforce a_id < b_id ordering for uniqueness
      user_a, user_b = [ai, target_ai].sort_by(&:id)
      AiDmThread.find_or_create_by!(
        ai_user_a: user_a,
        ai_user_b: user_b
      ) do |t|
        t.status = :active
        t.last_message_at = Time.current
      end
    end
  end

  def handle_violation(ai, reason)
    ai.increment!(:violation_count)
    ai.update!(is_active: false) if ai.violation_count >= 3
    Rails.logger.warn("DmGenerateJob violation for ai_id=#{ai.id}: #{reason}")
  end

  def broadcast_dm(thread, message)
    ActionCable.server.broadcast("global_timeline", {
      type: "new_dm",
      thread: DmThreadSerializer.new(thread).as_json,
      message: DmMessageSerializer.new(message).as_json
    })
  end
end
