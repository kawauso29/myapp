require 'mechanize'

agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'
page = agent.get('https://picro.jp/')
form = page.form_with(id: 'MemberIndexForm')
form.field_with(name: 'data[Member][loginid]').value = Rails.application.credentials.picro[:login_id]
form.field_with(name: 'data[Member][passwd]').value = Rails.application.credentials.picro[:password]
form.submit

inbox = agent.get('https://picro.jp/sports/amitie/messages/inbox')
box = inbox.at('#message_box')

if box
  puts box.to_html[0, 2000]
else
  puts 'message_box not found'
  puts inbox.body[0, 2000]
end
