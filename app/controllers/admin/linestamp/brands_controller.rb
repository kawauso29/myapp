class Admin::Linestamp::BrandsController < Admin::BaseController
  before_action :set_brand, only: %i[show update_line_meta update upload_base purge_base]

  def index
    @brands = ::Linestamp::Brand.order(updated_at: :desc)
  end

  def show
    @themes = ::Linestamp::CommunicationTheme.active.ordered
    @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
  end

  def update
    if @brand.update(brand_params)
      sync_themes
      sync_attribute_values
      redirect_to admin_linestamp_brand_path(@brand), notice: "ブランドを更新しました"
    else
      @themes = ::Linestamp::CommunicationTheme.active.ordered
      @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
      render :show, status: :unprocessable_entity
    end
  end

  def upload_base
    if params[:base_image].present?
      @brand.base_image.attach(params[:base_image])
      @brand.mark_base_ready! if @brand.may_mark_base_ready?
      redirect_to admin_linestamp_brand_path(@brand), notice: "Base image uploaded."
    else
      redirect_to admin_linestamp_brand_path(@brand), alert: "No file selected."
    end
  end

  def purge_base
    @brand.base_image.purge
    redirect_to admin_linestamp_brand_path(@brand), notice: "Base image removed."
  end

  def update_line_meta
    if @brand.update(line_meta_params)
      redirect_to admin_linestamp_brand_path(@brand), notice: "LINE申請メタデータ(ブランド)を保存しました"
    else
      redirect_to admin_linestamp_brand_path(@brand), alert: "保存に失敗しました: #{@brand.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_brand
    @brand = ::Linestamp::Brand.find(params[:id])
  end

  def line_meta_params
    params.require(:linestamp_brand).permit(:line_creator_name, :line_copyright, :line_category)
  end

  def brand_params
    params.require(:linestamp_brand).permit(:persona_name)
  end

  def sync_themes
    theme_ids = Array(params.dig(:linestamp_brand, :communication_theme_ids)).compact_blank.map(&:to_i)
    @brand.brand_communication_themes.where.not(communication_theme_id: theme_ids).destroy_all
    theme_ids.each do |tid|
      @brand.brand_communication_themes.find_or_create_by!(communication_theme_id: tid)
    end
  end

  def sync_attribute_values
    value_ids = Array(params.dig(:linestamp_brand, :attribute_value_ids)).compact_blank.map(&:to_i)
    @brand.brand_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
    value_ids.each do |vid|
      @brand.brand_attribute_values.find_or_create_by!(attribute_value_id: vid)
    end
  end
end
