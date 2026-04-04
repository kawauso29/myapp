class Admin::UsersController < Admin::BaseController
  PER_PAGE = 30

  def index
    page = [params[:page].to_i, 1].max
    offset = (page - 1) * PER_PAGE

    @users = User.includes(:ai_users)
                 .order(created_at: :desc)
                 .offset(offset)
                 .limit(PER_PAGE)

    @total_count = User.count
    @page = page
    @total_pages = (@total_count.to_f / PER_PAGE).ceil

    @stats = {
      total: User.count,
      free: User.where(plan: "free").count,
      light: User.where(plan: "light").count,
      premium: User.where(plan: "premium").count,
      with_ai: User.joins(:ai_users).distinct.count
    }
  end
end
