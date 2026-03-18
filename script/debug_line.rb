puts Gem.find_files("line/bot.rb").inspect
puts Gem.find_files("line_bot_api.rb").inspect

begin
  require "line/bot"
  puts "require 'line/bot' => OK"
  puts Line::Bot::Client.inspect
rescue => e
  puts "require 'line/bot' => #{e}"
end

begin
  require "line_bot_api"
  puts "require 'line_bot_api' => OK"
rescue => e
  puts "require 'line_bot_api' => #{e}"
end
