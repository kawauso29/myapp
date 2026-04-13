class Admin::PicroNotificationsController < Admin::BaseController
  def index
    @messages = PicroMessage.order(received_at: :desc).limit(100)
    @stats = {
      total: PicroMessage.count,
      today: PicroMessage.where("received_at >= ?", Time.current.beginning_of_day).count,
      notified: PicroMessage.where(notified: true).count,
      unnotified: PicroMessage.where(notified: false).count
    }
  end
end
