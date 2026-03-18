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
messages.first(3).each do |item|
  puts "---"
  puts "ID: #{item['MessageInbox']['id']}"
  puts "件名: #{item['Message']['subject']}"
  puts "受信: #{item['MessageInbox']['recieved']}"
  puts "フィールド: #{item['Message'].keys.join(', ')}"
end
