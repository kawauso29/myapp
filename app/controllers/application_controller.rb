class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from StandardError do |e|
    notify_slack_on_error(e)
    raise e
  end

  private

  def notify_slack_on_error(exception)
    return unless Rails.env.production?
    SlackNotifierService.notify(
      text: ":rotating_light: *アプリケーションエラー (Web)*",
      color: :danger,
      fields: [
        { title: "エラー",      value: "#{exception.class}: #{exception.message}" },
        { title: "コントローラ", value: "#{controller_name}##{action_name}" },
        { title: "パス",        value: request.fullpath },
        { title: "IPアドレス",  value: request.remote_ip }
      ]
    )
  end
end
