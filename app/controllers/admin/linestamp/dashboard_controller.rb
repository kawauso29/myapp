class Admin::Linestamp::DashboardController < Admin::BaseController
  def index
    @brands_count = ::Linestamp::Brand.count
    @packs_count = ::Linestamp::Pack.count
    @stamps_total = ::Linestamp::Stamp.count
    @stamps_processed = ::Linestamp::Stamp.where(status: "processed").count
    @submissions_count = ::Linestamp::Submission.count
    @recent_brands = ::Linestamp::Brand.order(updated_at: :desc).limit(5)
    @recent_packs = ::Linestamp::Pack.includes(:brand).order(updated_at: :desc).limit(5)

    # Phase 3 analytics
    @published_packs_count = ::Linestamp::Pack.published.count
    @best_sellers = ::Linestamp::Pack.best_sellers(10).includes(:brand)
    @attribute_sales = attribute_sales_summary
    @theme_sales = theme_sales_summary
    @pending_seeds_count = ::Linestamp::SeedApplication.pending.count
    @failed_seeds_count = ::Linestamp::SeedApplication.failed.count
    @failed_seeds = ::Linestamp::SeedApplication.failed.order(updated_at: :desc).limit(5)
  end

  private

  def attribute_sales_summary
    ::Linestamp::AttributeValue
      .joins(:axis, :pack_attribute_values)
      .joins("INNER JOIN linestamp_packs ON linestamp_packs.id = linestamp_pack_attribute_values.pack_id")
      .where.not(linestamp_packs: { published_at: nil })
      .group("linestamp_attribute_axes.name", "linestamp_attribute_values.name")
      .sum("linestamp_packs.sales_count")
      .sort_by { |_k, v| -v }
      .first(20)
  end

  def theme_sales_summary
    ::Linestamp::CommunicationTheme
      .joins(:pack_communication_themes)
      .joins("INNER JOIN linestamp_packs ON linestamp_packs.id = linestamp_pack_communication_themes.pack_id")
      .where.not(linestamp_packs: { published_at: nil })
      .group("linestamp_communication_themes.name")
      .sum("linestamp_packs.sales_count")
      .sort_by { |_k, v| -v }
  end
end
