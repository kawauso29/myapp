require "line/bot"
puts Line::Bot::Client.inspect

creds = Rails.application.credentials.line!
client = Line::Bot::Client.new do |config|
  config.channel_secret = creds[:channel_secret]
  config.channel_token  = creds[:channel_token]
end

response = client.push_message(creds[:user_id], [{ type: "text", text: "Picroテスト通知 動作確認OK!" }])
puts "HTTP status: #{response.code}"
