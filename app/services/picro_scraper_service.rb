class PicroScraperService
  BASE_URL = "https://picro.jp"
  LOGIN_URL = "#{BASE_URL}/".freeze
  MESSAGES_URL = "#{BASE_URL}/sports/amitie/messages/searchInboxMessages/1".freeze

  Result = Data.define(:success, :messages, :error)

  def call
    agent = build_agent
    login(agent)
    messages = fetch_messages(agent)
    Result.new(success: true, messages: messages, error: nil)
  rescue => e
    Rails.logger.error("[PicroScraperService] #{e.class}: #{e.message}")
    Result.new(success: false, messages: [], error: e.message)
  end

  private

  def build_agent
    agent = Mechanize.new
    agent.user_agent_alias = "Mac Safari"
    agent
  end

  def login(agent)
    page = agent.get(LOGIN_URL)

    form = page.form_with(id: "MemberIndexForm")
    raise "ログインフォームが見つかりません" unless form

    login_field    = form.field_with(name: "data[Member][loginid]")
    password_field = form.field_with(name: "data[Member][passwd]")

    raise "ログインIDフィールドが見つかりません" unless login_field
    raise "パスワードフィールドが見つかりません" unless password_field

    login_field.value = picro_credentials[:login_id]
    password_field.value = picro_credentials[:password]

    result_page = form.submit
    raise "ログイン失敗（ログインページに戻されました）" if login_page?(result_page)

    Rails.logger.info("[PicroScraperService] ログイン成功")
  end

  def fetch_messages(agent)
    page = agent.get(MESSAGES_URL)
    parse_messages(page)
  end

  def parse_messages(page)
    messages = []

    page.search("tr.messages--box--list-item").each do |row|
      sender   = row.at("td.messages--box--name")&.text&.strip
      date_str = row.at("td.messages--box--date")&.text&.strip
      title_td = row.at("td.messages--box--title")
      title    = title_td&.children&.first&.text&.strip
      preview  = title_td&.at("p.messages--box--excerpt")&.text&.strip&.truncate(200)

      next if sender.blank? || date_str.blank?

      messages << {
        message_id:  build_message_id(sender, date_str),
        sender_name: sender,
        title:       title,
        preview:     preview,
        received_at: parse_date(date_str)
      }
    end

    Rails.logger.info("[PicroScraperService] #{messages.size}件取得")
    messages
  end

  def build_message_id(sender, date_str)
    Digest::SHA1.hexdigest("#{sender}|#{date_str}")[0, 16]
  end

  def parse_date(text)
    return nil if text.blank?
    Time.zone.parse(text.strip)
  rescue ArgumentError
    nil
  end

  def login_page?(page)
    page.uri.to_s.include?("login") || page.search("#MemberLoginid").any?
  end

  def picro_credentials
    Rails.application.credentials.picro!
  end
end
