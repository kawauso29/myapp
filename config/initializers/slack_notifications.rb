# Rack::Attack throttle → Slack通知
ActiveSupport::Notifications.subscribe("rack.attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  next unless req.env["rack.attack.match_type"] == :throttle
  SlackNotifierService.notify(
    text: ":no_entry: *レート制限トリガー*",
    color: :warning,
    fields: [
      { title: "ルール",  value: req.env["rack.attack.matched"] },
      { title: "IP",      value: req.ip },
      { title: "パス",    value: req.path },
      { title: "メソッド", value: req.request_method }
    ]
  )
end
