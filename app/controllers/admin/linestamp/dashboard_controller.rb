class Admin::Linestamp::DashboardController < Admin::BaseController
  def index
    @brands_count = ::Linestamp::Brand.count
    @packs_count = ::Linestamp::Pack.count
    @stamps_total = ::Linestamp::Stamp.count
    @stamps_processed = ::Linestamp::Stamp.where(status: "processed").count
    @submissions_count = ::Linestamp::Submission.count
    @recent_brands = ::Linestamp::Brand.order(updated_at: :desc).limit(5)
    @recent_packs = ::Linestamp::Pack.includes(:brand).order(updated_at: :desc).limit(5)
  end
end
