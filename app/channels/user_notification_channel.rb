class UserNotificationChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user
    stream_for current_user
  end

  def unsubscribed
    # cleanup
  end
end
