class Linestamp::WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

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
end
