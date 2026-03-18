require "line/bot"
consts = Line::Bot::V2::MessagingApi.constants.map(&:to_s)
puts consts.grep(/[Cc]lient|[Aa]pi/).inspect
