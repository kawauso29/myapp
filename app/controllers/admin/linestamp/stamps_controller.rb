class Admin::Linestamp::StampsController < Admin::BaseController
  before_action :set_stamp, only: %i[show update upload_raw upload_processed process_image reset designer_kit]

  def show
    @themes = ::Linestamp::CommunicationTheme.active.ordered
    @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
  end

  def update
    update_primary_theme
    sync_secondary_themes
    sync_attribute_values
    redirect_to admin_linestamp_stamp_path(@stamp), notice: "スタンプを更新しました"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_linestamp_stamp_path(@stamp), alert: e.message
  end

  def upload_raw
    if params[:raw_image].present?
      @stamp.raw_image.attach(params[:raw_image])
      @stamp.upload_raw! if @stamp.may_upload_raw?
      redirect_to admin_linestamp_stamp_path(@stamp), notice: "Raw image uploaded."
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "No file selected."
    end
  end

  def upload_processed
    if params[:processed_image].present?
      @stamp.processed_image.attach(params[:processed_image])
      @stamp.upload_processed_directly! if @stamp.may_upload_processed_directly?
      redirect_to admin_linestamp_stamp_path(@stamp), notice: "Processed image uploaded directly."
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "No file selected."
    end
  end

  def process_image
    if @stamp.may_start_processing? || @stamp.raw_uploaded?
      ::Linestamp::ProcessStampImageJob.perform_later(@stamp.id)
      redirect_to admin_linestamp_stamp_path(@stamp), notice: "Processing started."
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "Stamp cannot be processed in current state."
    end
  end

  def reset
    if @stamp.may_reset?
      @stamp.processed_image.purge if @stamp.processed_image.attached?
      @stamp.reset!
      redirect_to admin_linestamp_stamp_path(@stamp), notice: "Stamp reset to raw_uploaded."
    else
      redirect_to admin_linestamp_stamp_path(@stamp), alert: "Cannot reset stamp in current state."
    end
  end

  def designer_kit
    kit = ::Linestamp::DesignerKit::Stamp.new(@stamp)
    zip = kit.export
    send_file zip.path, filename: kit.filename, type: "application/zip", disposition: "attachment"
  end

  private

  def set_stamp
    @stamp = ::Linestamp::Stamp.find(params[:id])
  end

  def update_primary_theme
    primary_theme_id = params.dig(:linestamp_stamp, :primary_communication_theme_id).presence&.to_i
    return unless primary_theme_id

    # Set primary on the join record
    @stamp.stamp_communication_themes.update_all(primary: false)
    join = @stamp.stamp_communication_themes.find_or_create_by!(communication_theme_id: primary_theme_id)
    join.update!(primary: true)
  end

  def sync_secondary_themes
    secondary_ids = Array(params.dig(:linestamp_stamp, :communication_theme_ids)).compact_blank.map(&:to_i)
    primary_theme_id = params.dig(:linestamp_stamp, :primary_communication_theme_id).presence&.to_i
    all_theme_ids = (secondary_ids + [primary_theme_id]).compact.uniq

    @stamp.stamp_communication_themes.where.not(communication_theme_id: all_theme_ids).destroy_all
    all_theme_ids.each do |tid|
      @stamp.stamp_communication_themes.find_or_create_by!(communication_theme_id: tid)
    end
  end

  def sync_attribute_values
    value_ids = Array(params.dig(:linestamp_stamp, :attribute_value_ids)).compact_blank.map(&:to_i)
    @stamp.stamp_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
    value_ids.each do |vid|
      @stamp.stamp_attribute_values.find_or_create_by!(attribute_value_id: vid)
    end
  end
end
