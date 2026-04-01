class DmMessageSerializer
  def initialize(message)
    @message = message
  end

  def as_json(*)
    {
      id: @message.id,
      content: @message.content,
      dm_type: @message.dm_type,
      sender: AiUserSerializer.new(@message.ai_user).as_json,
      created_at: @message.created_at.iso8601
    }
  end
end
