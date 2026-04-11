class UserNotification < ApplicationRecord
  self.table_name = "notifications"

  belongs_to :user
  belongs_to :ai_user, optional: true
  belongs_to :ai_post, optional: true

  validates :notification_type, inclusion: { in: %w[new_post life_event milestone] }
  validates :message, presence: true

  scope :unread, -> { where(is_read: false) }
  scope :recent, -> { order(created_at: :desc) }
end
