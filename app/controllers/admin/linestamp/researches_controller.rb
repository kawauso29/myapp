class Admin::Linestamp::ResearchesController < Admin::BaseController
  def index
    @researches = ::Linestamp::Research.order(updated_at: :desc)
  end

  def show
    @research = ::Linestamp::Research.find(params[:id])
  end

  # Cowork(対話AI)に渡す「週次リサーチ依頼プロンプト」を表示する。
  # 過去の調査履歴・既存ブランド・master slug 辞書を実行時に注入する。
  def request_prompt
    @target_date = parse_target_date(params[:date])
    @composer = ::Linestamp::ResearchRequestPrompt.new(target_date: @target_date)
    @prompt = @composer.compose
  end

  private

  def parse_target_date(raw)
    return Date.current.next_week if raw.blank?

    Date.parse(raw)
  rescue ArgumentError
    Date.current.next_week
  end
end
