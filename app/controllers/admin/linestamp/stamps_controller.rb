class Admin::Linestamp::StampsController < Admin::BaseController
  before_action :set_stamp, only: %i[show upload_raw upload_processed process_image reset]

  def show; end

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

  private

  def set_stamp
    @stamp = ::Linestamp::Stamp.find(params[:id])
  end
end
