class Admin::Linestamp::BrandsController < Admin::BaseController
  before_action :set_brand, only: %i[show upload_base purge_base]

  def index
    @brands = ::Linestamp::Brand.order(updated_at: :desc)
  end

  def show; end

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

  private

  def set_brand
    @brand = ::Linestamp::Brand.find(params[:id])
  end
end
