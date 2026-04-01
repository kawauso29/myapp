class ExpiredMemoryCleanupJob < ApplicationJob
  queue_as :low

  def perform
    AiShortTermMemory.where("expires_at < ?", Time.current).delete_all
    JwtDenylist.where("exp < ?", Time.current).delete_all
  end
end
