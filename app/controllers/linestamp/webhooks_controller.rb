class Linestamp::WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_webhook_signature, only: :line_review_callback

  def sync
    Linestamp::SyncBrandSourcesJob.perform_later
    render json: { status: "accepted" }, status: :accepted
  end

  def line_review_callback
    # Webhook from LINE for submission review status updates
    payload = JSON.parse(request.body.read)

    item_id = payload["itemId"]
    status = payload["status"]

    submission = ::Linestamp::Submission.find_by(line_item_id: item_id)
    unless submission
      render json: { error: "Submission not found" }, status: :not_found
      return
    end

    case status
    when "approved"
      submission.approve! if submission.may_approve?
    when "rejected"
      submission.rejection_reason = payload["reason"]
      submission.reject! if submission.may_reject?
    end

    render json: { ok: true }
  rescue JSON::ParserError
    render json: { error: "Invalid JSON" }, status: :bad_request
  end

  private

  def verify_webhook_signature
    secret = ENV["SLACK_SIGNING_SECRET"]
    return if secret.blank? # Skip verification if secret not configured

    signature = request.headers["X-Line-Signature"]
    body = request.body.read
    request.body.rewind

    expected = Base64.strict_encode64(
      OpenSSL::HMAC.digest("SHA256", secret, body)
    )

    unless ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected)
      render json: { error: "Invalid signature" }, status: :unauthorized
    end
  end
end
