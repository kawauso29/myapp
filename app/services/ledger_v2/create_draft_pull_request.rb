# LedgerV2::CreateDraftPullRequest — 承認済み CI 修正案 Artifact を draft PR に昇格する。
#
# 責務:
# - ci_fix_suggestion Artifact が人間に accept された後だけ動作する
# - GitHub 上に draft PR を作成する
# - 作成結果を Artifact metadata_json と Event に記録する
#
# やらないこと:
# - Runner から直接 PR を作らない
# - draft 以外の PR を作らない
# - 自動マージ・自動デプロイしない
module LedgerV2
  class CreateDraftPullRequest
    Result = Struct.new(:created?, :skipped?, :pr_number, :pr_url, :reason, keyword_init: true)
    RETRYABLE_TERMINAL_REASONS = %w[pr_closed].freeze

    def self.call(artifact:)
      new(artifact: artifact).call
    end

    def initialize(artifact:)
      @artifact = artifact
    end

    def call
      return skipped("auto_pr disabled") unless Flags.enabled?(:auto_pr)
      return skipped("unsupported artifact_type") unless @artifact.artifact_type == "ci_fix_suggestion"
      return skipped("artifact is not accepted") unless @artifact.review_status_accepted?
      return skipped("draft PR already created") if active_pr_exists?

      result = GithubPrService.create_pr(
        title: pr_title,
        body: pr_body,
        branch_prefix: "copilot/ledger-v2-ci-fix-#{@artifact.id}",
        draft: true,
        path_prefix: "docs/ledger_v2_draft_prs"
      )

      if result && result["number"]
        record_success(result)
      else
        record_failure
      end
    rescue => e
      Rails.logger.error("[LedgerV2::CreateDraftPullRequest] #{e.class}: #{e.message}")
      record_failure(reason: e.message)
    end

    private

    def existing_pr_number
      @artifact.metadata_json&.dig("draft_pr", "number")
    end

    def current_draft_pr
      (@artifact.metadata_json || {}).fetch("draft_pr", {})
    end

    def active_pr_exists?
      return false if existing_pr_number.blank?
      return false if retryable_closed_pr?(current_draft_pr)

      true
    end

    def retryable_closed_pr?(draft_pr_metadata)
      draft_pr_metadata["pr_state"] == "closed" &&
        RETRYABLE_TERMINAL_REASONS.include?(draft_pr_metadata["ci_terminal_reason"])
    end

    def pr_title
      "ledger-v2: CI 修正案 Artifact ##{@artifact.id}"
    end

    def pr_body
      [
        "## Summary",
        "LedgerV2 の承認済み `ci_fix_suggestion` Artifact から作成された draft PR です。",
        "",
        "## Source",
        "- Artifact: ##{@artifact.id}",
        "- Ticket: #{ticket_label}",
        "- Run: #{run_label}",
        "",
        "## Guardrails",
        "- draft PR のみ作成",
        "- 自動マージしない",
        "- 自動デプロイ判断しない",
        "",
        "## Artifact Body",
        "",
        @artifact.body.to_s
      ].join("\n")
    end

    def ticket_label
      return "なし" unless @artifact.related_ticket

      "##{@artifact.related_ticket.id} #{@artifact.related_ticket.title}"
    end

    def run_label
      @artifact.run_id ? "##{@artifact.run_id}" : "なし"
    end

    def record_success(result)
      existing_draft_pr = current_draft_pr
      create_attempt_count = existing_draft_pr["create_attempt_count"].to_i + 1
      previous_pr_numbers = Array(existing_draft_pr["previous_pr_numbers"]).map(&:to_i)
      if retryable_closed_pr?(existing_draft_pr) && existing_draft_pr["number"].present?
        previous_pr_numbers |= [existing_draft_pr["number"].to_i]
      end

      metadata = merged_metadata(
        "draft_pr" => {
          "number" => result["number"],
          "url" => result["html_url"],
          "created_at" => Time.current.iso8601,
          "source" => "ledger_v2_ci_fix_suggestion",
          "create_status" => "created",
          "create_attempt_count" => create_attempt_count,
          "retried_from_pr_number" => retryable_closed_pr?(existing_draft_pr) ? existing_draft_pr["number"].to_i : nil,
          "previous_pr_numbers" => previous_pr_numbers,
          "creation_error" => nil,
          "creation_failed_at" => nil,
          "ci_status" => "pending",
          "ci_decision" => "continue",
          "ci_retry_count" => 0,
          "ci_terminal" => false,
          "ci_terminal_at" => nil,
          "ci_terminal_reason" => nil,
          "failed_checks" => []
        }
      )
      @artifact.update!(metadata_json: metadata)
      create_event(
        event_type: "draft_pr_created",
        severity: :info,
        message: "Artifact ##{@artifact.id} から draft PR ##{result['number']} を作成しました",
        payload: metadata["draft_pr"].merge(
          "artifact_id" => @artifact.id,
          "related_ticket_id" => @artifact.related_ticket_id
        )
      )

      Result.new(created?: true, skipped?: false, pr_number: result["number"], pr_url: result["html_url"])
    end

    def record_failure(reason: "GitHub PR creation failed")
      existing_draft_pr = current_draft_pr
      create_attempt_count = existing_draft_pr["create_attempt_count"].to_i + 1
      metadata = merged_metadata(
        "draft_pr" => existing_draft_pr.merge(
          "create_status" => "failed",
          "create_attempt_count" => create_attempt_count,
          "creation_error" => reason,
          "creation_failed_at" => Time.current.iso8601
        )
      )
      @artifact.update!(metadata_json: metadata)
      create_event(
        event_type: "draft_pr_create_failed",
        severity: :warning,
        message: "Artifact ##{@artifact.id} から draft PR を作成できませんでした: #{reason}",
        payload: {
          "artifact_id" => @artifact.id,
          "related_ticket_id" => @artifact.related_ticket_id,
          "reason" => reason
        }
      )
      Result.new(created?: false, skipped?: false, reason: reason)
    end

    def skipped(reason)
      Result.new(created?: false, skipped?: true, reason: reason)
    end

    def merged_metadata(extra)
      (@artifact.metadata_json || {}).merge(extra)
    end

    def create_event(event_type:, severity:, message:, payload:)
      return unless @artifact.run

      Event.create!(
        run: @artifact.run,
        event_type: event_type,
        severity: severity,
        occurred_at: Time.current,
        message: message,
        payload_json: payload,
        subject_type: "LedgerV2::Artifact",
        subject_id: @artifact.id
      )
    end
  end
end
