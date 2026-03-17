class PicroScraperService
  BASE_URL = "https://picro.jp"
  LOGIN_URL = "#{BASE_URL}/".freeze
  MESSAGES_URL = "#{BASE_URL}/members/messages/".freeze

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

    form = page.form_with(action: /login|member/i) || page.forms.first
    raise "ログインフォームが見つかりません" unless form

    # フィールド名は実際のHTMLに合わせて調整が必要
    # ブラウザDevToolsで form の action と input の name を確認すること
    login_field = form.field_with(id: "MemberLoginid") ||
                  form.field_with(name: /login_id|email|loginid/i)
    password_field = form.field_with(name: /password|passwd/i)

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

  # メッセージ一覧のHTML構造に合わせてパース処理を調整すること
  # ブラウザDevToolsでメッセージ一覧ページの構造を確認の上、
  # セレクタを修正してください
  def parse_messages(page)
    messages = []

    # TODO: 実際のHTML構造を確認してセレクタを調整
    # 例: page.search(".message-item") など
    page.search(".message-list-item, .message-row, li.message").each do |node|
      message_id = extract_message_id(node)
      next if message_id.nil?

      messages << {
        message_id: message_id,
        sender_name: node.at(".sender-name, .from, .username")&.text&.strip,
        preview: node.at(".message-preview, .body, .content")&.text&.strip&.truncate(100),
        received_at: parse_date(node.at(".date, .time, .received-at")&.text)
      }
    end

    Rails.logger.info("[PicroScraperService] #{messages.size}件取得")
    messages
  end

  def extract_message_id(node)
    # data-id属性 or リンクのIDパラメータから取得
    node["data-id"] ||
      node.at("a[href*='/messages/']")&.[]("href")&.match(%r{/messages/(\w+)})&.[](1)
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
