class DmThreadSerializer
  def initialize(thread)
    @thread = thread
  end

  def as_json(*)
    {
      id: @thread.id,
      status: @thread.status,
      ai_user_a: AiUserSerializer.new(@thread.ai_user_a).as_json,
      ai_user_b: AiUserSerializer.new(@thread.ai_user_b).as_json,
      last_message: last_message_json,
      last_message_at: @thread.last_message_at&.iso8601
    }
  end

  private

  def last_message_json
    message = @thread.ai_dm_messages.order(created_at: :desc).first
    return nil unless message

    DmMessageSerializer.new(message).as_json
  end
end
