class Admin::LedgerV2::ArtifactsController < Admin::LedgerV2::BaseController
  # Ticket 15: Artifact Review UI
  # 人間が Artifact を accept / reject / defer / publish / reopen できる画面。
  # 運用ルール §7: Artifact は人間レビュー必須。
  # 運用ルール §10: 自動マージ・自動 publish は禁止。

  VALID_REVIEW_ACTIONS = %w[accept reject defer publish reopen].freeze

  def index
    scope = ::LedgerV2::Artifact.order(created_at: :desc)

    scope = scope.where(review_status: filtered_status) if filtered_status.present?
    scope = scope.where(artifact_type: filtered_type)   if filtered_type.present?

    @artifacts = scope.limit(50)
    @filter_status = filtered_status
    @filter_type   = filtered_type
  end

  def show
    @artifact = ::LedgerV2::Artifact.find(params[:id])
  end

  # PATCH /admin/ledger_v2/artifacts/:id
  # params[:review_action] は "accept" / "reject" / "defer" / "publish" / "reopen" のいずれか。
  def update
    @artifact = ::LedgerV2::Artifact.find(params[:id])
    action    = params[:review_action].to_s

    unless VALID_REVIEW_ACTIONS.include?(action)
      return redirect_to admin_ledger_v2_artifacts_path, alert: "不正な操作です: #{action}"
    end

    apply_review_action(@artifact, action)
  end

  private

  def apply_review_action(artifact, action)
    case action
    when "accept"
      artifact.update!(
        review_status: :accepted,
        reviewed_by:   "admin",
        reviewed_at:   Time.current
      )
      redirect_to admin_ledger_v2_artifacts_path, notice: "Artifact ##{artifact.id} を accept しました。"
    when "reject"
      artifact.update!(
        review_status:  :review_rejected,
        reviewed_by:    "admin",
        reviewed_at:    Time.current,
        review_comment: params[:review_comment].presence
      )
      redirect_to admin_ledger_v2_artifacts_path, notice: "Artifact ##{artifact.id} を reject しました。"
    when "defer"
      artifact.update!(
        review_status: :review_deferred,
        reviewed_by:   "admin",
        reviewed_at:   Time.current
      )
      redirect_to admin_ledger_v2_artifacts_path, notice: "Artifact ##{artifact.id} を defer しました。"
    when "publish"
      artifact.update!(
        review_status: :published,
        reviewed_by:   "admin",
        reviewed_at:   Time.current,
        published_at:  Time.current
      )
      redirect_to admin_ledger_v2_artifacts_path, notice: "Artifact ##{artifact.id} を publish しました。"
    when "reopen"
      artifact.update!(
        review_status:  :pending,
        reviewed_by:    nil,
        reviewed_at:    nil,
        review_comment: nil
      )
      redirect_to admin_ledger_v2_artifacts_path, notice: "Artifact ##{artifact.id} を reopen しました。"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ledger_v2_artifacts_path, alert: "更新に失敗しました: #{e.message}"
  end

  def filtered_status
    params[:status].presence
  end

  def filtered_type
    params[:artifact_type].presence
  end
end
