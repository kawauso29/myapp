class Admin::Linestamp::ResearchesController < Admin::BaseController
  def index
    @researches = ::Linestamp::Research.order(updated_at: :desc)
  end

  def show
    @research = ::Linestamp::Research.find(params[:id])
  end
end
