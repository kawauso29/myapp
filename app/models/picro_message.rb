class PicroMessage < ApplicationRecord
  validates :message_id, presence: true, uniqueness: true

  scope :unnotified, -> { where(notified: false) }

  def self.new_message_ids(fetched_ids)
    fetched_ids - where(message_id: fetched_ids).pluck(:message_id)
  end
end
