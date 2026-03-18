require 'mechanize'

agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'
page = agent.get('https://picro.jp/')
form = page.form_with(id: 'MemberIndexForm')
form.field_with(name: 'data[Member][loginid]').value = Rails.application.credentials.picro[:login_id]
form.field_with(name: 'data[Member][passwd]').value = Rails.application.credentials.picro[:password]
form.submit

inbox = agent.get('https://picro.jp/sports/amitie/messages/searchInboxMessages/1')
puts 'Content-Type: ' + inbox.response['content-type'].to_s
puts inbox.body[0, 3000]
