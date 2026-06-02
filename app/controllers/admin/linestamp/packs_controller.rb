class Admin::Linestamp::PacksController < Admin::BaseController
  before_action :set_pack, only: %i[show update upload_sheet approve export_for_line import_zip upload_main_image generate_main_image upload_tab_image generate_tab_image]

  def index
    @packs = ::Linestamp::Pack.includes(:brand).order(updated_at: :desc)
  end

  def show
    @stamps = @pack.stamps.order(:position)
    @themes = ::Linestamp::CommunicationTheme.active.ordered
    @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
  end

  def update
    if @pack.update(pack_params)
      sync_themes
      sync_attribute_values
      redirect_to admin_linestamp_pack_path(@pack), notice: "シリーズを更新しました"
    else
      @stamps = @pack.stamps.order(:position)
      @themes = ::Linestamp::CommunicationTheme.active.ordered
      @attribute_values = ::Linestamp::AttributeValue.active.ordered.includes(:axis)
      render :show, status: :unprocessable_entity
    end
  end

  def upload_sheet
    if params[:sheet_image].present?
      @pack.sheet_image.attach(params[:sheet_image])
      redirect_to admin_linestamp_pack_path(@pack), notice: "Sheet image uploaded."
    else
      redirect_to admin_linestamp_pack_path(@pack), alert: "No file selected."
    end
  end

  def upload_main_image
    if params[:main_image].present?
      @pack.main_image.attach(params[:main_image])
      redirect_to admin_linestamp_pack_path(@pack), notice: "Main image uploaded."
    else
      redirect_to admin_linestamp_pack_path(@pack), alert: "No file selected."
    end
  end

  def generate_main_image
    source_stamp = @pack.stamps.find(params[:source_stamp_id])
    ::Linestamp::PackRepresentativeImageGenerator.new.call(pack: @pack, kind: :main, source_stamp: source_stamp)
    redirect_to admin_linestamp_pack_path(@pack), notice: "Main image generated from stamp ##{source_stamp.position}."
  rescue StandardError => e
    redirect_to admin_linestamp_pack_path(@pack), alert: "Generation failed: #{e.message}"
  end

  def upload_tab_image
    if params[:tab_image].present?
      @pack.tab_image.attach(params[:tab_image])
      redirect_to admin_linestamp_pack_path(@pack), notice: "Tab image uploaded."
    else
      redirect_to admin_linestamp_pack_path(@pack), alert: "No file selected."
    end
  end

  def generate_tab_image
    source_stamp = @pack.stamps.find(params[:source_stamp_id])
    ::Linestamp::PackRepresentativeImageGenerator.new.call(pack: @pack, kind: :tab, source_stamp: source_stamp)
    redirect_to admin_linestamp_pack_path(@pack), notice: "Tab image generated from stamp ##{source_stamp.position}."
  rescue StandardError => e
    redirect_to admin_linestamp_pack_path(@pack), alert: "Generation failed: #{e.message}"
  end

  # LINE申請用 ZIP を1つ受け取り、中身を Stamp / main / tab へ一括添付する。
  # export_for_line(LineExporter) の逆操作。命名規約は LineExporter と対称:
  #   NN.png → position==NN の Stamp、main.png → main_image、tab.png → tab_image
  def import_zip
    uploaded = params[:line_zip]
    if uploaded.blank?
      redirect_to admin_linestamp_pack_path(@pack), alert: "ZIPファイルを選択してください。"
      return
    end

    stamp_count = 0
    main_done = false
    tab_done = false
    skipped = []

    Zip::File.open(uploaded.path) do |zip|
      zip.each do |entry|
        next if entry.directory?

        name = File.basename(entry.name.to_s)
        next if name.start_with?(".", "__")

        case name
        when /\A0*(\d+)\.png\z/i
          position = Regexp.last_match(1).to_i
          stamp = @pack.stamps.find_by(position: position)
          if stamp.nil?
            skipped << name
            next
          end
          stamp.processed_image.attach(
            io: StringIO.new(entry.get_input_stream.read),
            filename: format("%02d.png", position),
            content_type: "image/png"
          )
          stamp.upload_processed_directly! if stamp.may_upload_processed_directly?
          stamp_count += 1
        when /\Amain\.png\z/i
          @pack.main_image.attach(
            io: StringIO.new(entry.get_input_stream.read),
            filename: "main.png",
            content_type: "image/png"
          )
          main_done = true
        when /\Atab\.png\z/i
          @pack.tab_image.attach(
            io: StringIO.new(entry.get_input_stream.read),
            filename: "tab.png",
            content_type: "image/png"
          )
          tab_done = true
        else
          skipped << name
        end
      end
    end

    # 全スタンプ揃ったら Approve / Export を解放できる状態まで前進させる(各ガード付き)。
    @pack.start_work! if @pack.may_start_work?
    @pack.mark_stamps_complete! if @pack.all_stamps_processed? && @pack.may_mark_stamps_complete?

    parts = ["スタンプ #{stamp_count} 枚"]
    parts << "メイン画像" if main_done
    parts << "タブ画像" if tab_done
    notice = "ZIP取り込み完了: #{parts.join(' / ')} を登録しました。"
    notice += " (スキップ: #{skipped.join(', ')})" if skipped.any?
    redirect_to admin_linestamp_pack_path(@pack), notice: notice
  rescue StandardError => e
    redirect_to admin_linestamp_pack_path(@pack), alert: "ZIP取り込み失敗: #{e.message}"
  end

  def approve
    if @pack.may_approve?
      @pack.approve!
      redirect_to admin_linestamp_pack_path(@pack), notice: "Pack approved."
    else
      redirect_to admin_linestamp_pack_path(@pack), alert: "Pack cannot be approved in current state."
    end
  end

  def export_for_line
    unless @pack.approved? || @pack.submitted?
      redirect_to admin_linestamp_pack_path(@pack), alert: "Pack must be approved before export."
      return
    end

    exporter = ::Linestamp::LineExporter.new(@pack)
    zip_file = exporter.export
    zip_path = zip_file.path.to_s

    safe_slug = @pack.brand.slug.gsub(/[^a-zA-Z0-9_\-]/, "")
    safe_filename = "linestamp_#{safe_slug}_pack#{@pack.position.to_i}.zip"

    zip_data = IO.binread(zip_path) # brakeman:disable:FileAccess
    send_data zip_data,
              filename: safe_filename,
              type: "application/zip",
              disposition: "attachment"
  rescue StandardError => e
    redirect_to admin_linestamp_pack_path(@pack), alert: "Export failed: #{e.message}"
  end

  private

  def set_pack
    @pack = ::Linestamp::Pack.find(params[:id])
  end

  def pack_params
    params.require(:linestamp_pack).permit(:purchase_unit_size, :published_at, :sales_count)
  end

  def sync_themes
    theme_ids = Array(params.dig(:linestamp_pack, :communication_theme_ids)).compact_blank.map(&:to_i)
    @pack.pack_communication_themes.where.not(communication_theme_id: theme_ids).destroy_all
    theme_ids.each do |tid|
      @pack.pack_communication_themes.find_or_create_by!(communication_theme_id: tid)
    end
  end

  def sync_attribute_values
    value_ids = Array(params.dig(:linestamp_pack, :attribute_value_ids)).compact_blank.map(&:to_i)
    @pack.pack_attribute_values.where.not(attribute_value_id: value_ids).destroy_all
    value_ids.each do |vid|
      @pack.pack_attribute_values.find_or_create_by!(attribute_value_id: vid)
    end
  end
end
