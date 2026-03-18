require 'mechanize'

agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'
page = agent.get('https://picro.jp/')
form = page.form_with(id: 'MemberIndexForm')
form.field_with(name: 'data[Member][loginid]').value = Rails.application.credentials.picro[:login_id]
form.field_with(name: 'data[Member][passwd]').value = Rails.application.credentials.picro[:password]
form.submit

response = agent.get('https://picro.jp/sports/amitie/messages/searchInboxMessages/1')
data = JSON.parse(response.body)
messages = data['data'] || []
puts "#{messages.size}件取得"
item = messages.first
puts "top-level keys: #{item.keys.join(', ')}"
item.each do |k, v|
  next if %w[MessageInbox Message].include?(k)
  puts "#{k}: #{v.inspect}"
end
