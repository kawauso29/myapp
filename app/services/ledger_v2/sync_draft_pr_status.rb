# LedgerV2::SyncDraftPrStatus — draft PR の CI 状態を Ledger V2 に同期する。
#
# 責務:
# - draft PR を持つ ci_fix_suggestion Artifact の CI 状態を GitHub から読取る
# - CI 状態を Artifact metadata_json["draft_pr"] に保存する
# - 判定結果を continue / stop / human_escalate の Event として記録する
# - HealthSnapshot が ci_repass_rate を計測できる状態を整える
#
# やらないこと:
# - draft 以外の PR を作らない
# - 自動マージ・自動デプロイを実行しない
# - Artifact / Ticket の review_status を自動変更しない
module LedgerV2
  class SyncDraftPrStatus
    MAX_PENDING_RETRIES = 3

    TRACKED_DRAFT_PR_FIELDS = %w[
      ci_status
      ci_conclusion
      ci_decision
      ci_retry_count
      ci_terminal
      ci_terminal_at
      ci_terminal_reason
      failed_checks
      head_sha
      ci_sync_error
      create_status
      creation_error
    ].freeze

    def self.call(run:, dry_run: false, **)
      new(run: run, dry_run: dry_run).call
    end

    def initialize(run:, dry_run:)
      @run = run
      @dry_run = dry_run
    end

    def call
      created_event_count = 0

      draft_pr_artifacts.find_each do |artifact|
        sync_result = sync_artifact(artifact)
        created_event_count += sync_result[:created_event_count]
      end

      RunExecutor::RunnerResult.new(created_event_count: created_event_count)
    end

    private

    attr_reader :run, :dry_run

    def draft_pr_artifacts
      Artifact.where(artifact_type: "ci_fix_suggestion")
              .where("metadata_json ? :key", key: "draft_pr")
    end

    def sync_artifact(artifact)
      current_draft_pr = artifact.metadata_json.fetch("draft_pr", {})
      return { created_event_count: 0 } if current_draft_pr["ci_terminal"] == true

      pr_number = current_draft_pr["number"]
      return { created_event_count: 0 } if pr_number.blank?

      ci_status = GithubPrService.fetch_ci_status(pr_number: pr_number)
      return sync_failure(artifact, pr_number) if ci_status.blank?

      retry_count = next_retry_count(current_draft_pr, ci_status["status"])
      decision_result = decision_for(status: ci_status["status"], retry_count: retry_count)
      decision = decision_result.fetch(:decision)
      metadata = build_metadata(artifact, ci_status, decision_result, retry_count)
      return { created_event_count: 0 } unless state_changed?(artifact, metadata)

      return { created_event_count: 0 } if dry_run

      artifact.update!(metadata_json: metadata)

      created_event_count = create_decision_events(artifact, ci_status, decision_result, retry_count)
      { created_event_count: created_event_count }
    end

    def sync_failure(artifact, pr_number)
      metadata = merged_metadata(
        artifact,
        "draft_pr" => artifact.metadata_json.fetch("draft_pr", {}).merge(
          "ci_status" => "unknown",
          "ci_sync_error" => "GitHub CI status fetch failed",
          "ci_checked_at" => Time.current.iso8601
        )
      )
      return { created_event_count: 0 } if dry_run
      return { created_event_count: 0 } unless state_changed?(artifact, metadata)

      artifact.update!(metadata_json: metadata)
      create_event(
        artifact: artifact,
        event_type: "draft_pr_ci_sync_failed",
        severity: :warning,
        message: "Artifact ##{artifact.id} の draft PR ##{pr_number} の CI 状態取得に失敗しました",
        payload: {
          "artifact_id" => artifact.id,
          "pr_number" => pr_number.to_i,
          "ci_status" => "unknown"
        }
      )
      { created_event_count: 1 }
    end

    def build_metadata(artifact, ci_status, decision_result, retry_count)
      existing_draft_pr = artifact.metadata_json.fetch("draft_pr", {})
      terminal = decision_result.fetch(:terminal)
      draft_pr_metadata = existing_draft_pr.merge(
        "ci_status" => ci_status["status"],
        "ci_conclusion" => ci_status["conclusion"],
        "ci_decision" => decision_result.fetch(:decision),
        "ci_retry_count" => retry_count,
        "ci_terminal" => terminal,
        "ci_terminal_at" => terminal_timestamp(existing_draft_pr, terminal),
        "ci_terminal_reason" => terminal ? decision_result.fetch(:terminal_reason) : nil,
        "ci_checked_at" => Time.current.iso8601,
        "failed_checks" => ci_status["failed_checks"],
        "head_sha" => ci_status["head_sha"],
        "check_runs" => ci_status["check_runs"]
      )

      merged_metadata(artifact, "draft_pr" => draft_pr_metadata)
    end

    def next_retry_count(current_draft_pr, status)
      current_count = current_draft_pr["ci_retry_count"].to_i
      return current_count + 1 if status == "pending"

      current_count
    end

    def decision_for(status:, retry_count:)
      return terminal_decision("human_escalate", "ci_failed") if status == "failure"
      return terminal_decision("stop", "auto_merge_disabled") unless Flags.enabled?(:auto_merge)
      return terminal_decision("continue", "ci_passed") if status == "success"

      return terminal_decision("human_escalate", "ci_pending_timeout") if status == "pending" && retry_count >= MAX_PENDING_RETRIES

      { decision: "continue", terminal: false, terminal_reason: nil }
    end

    def terminal_decision(decision, reason)
      { decision: decision, terminal: true, terminal_reason: reason }
    end

    def terminal_timestamp(current_draft_pr, terminal)
      return current_draft_pr["ci_terminal_at"] if current_draft_pr["ci_terminal"] == true
      return Time.current.iso8601 if terminal

      nil
    end

    def state_changed?(artifact, metadata)
      current_draft_pr = artifact.metadata_json.fetch("draft_pr", {})
      next_draft_pr = metadata.fetch("draft_pr", {})

      TRACKED_DRAFT_PR_FIELDS.any? do |key|
        current_draft_pr[key] != next_draft_pr[key]
      end
    end

    def merged_metadata(artifact, extra)
      (artifact.metadata_json || {}).merge(extra)
    end

    def create_decision_events(artifact, ci_status, decision_result, retry_count)
      decision = decision_result.fetch(:decision)
      terminal = decision_result.fetch(:terminal)

      create_decision_event(artifact, ci_status, decision, decision_result.fetch(:terminal_reason), terminal, retry_count)
      created_event_count = 1

      if terminal
        create_terminal_event(artifact, ci_status, decision, decision_result.fetch(:terminal_reason), retry_count)
        created_event_count += 1
      elsif ci_status["status"] == "pending"
        create_retrying_event(artifact, ci_status, retry_count)
        created_event_count += 1
      end

      created_event_count
    end

    def create_decision_event(artifact, ci_status, decision, terminal_reason, terminal, retry_count)
      severity =
        case decision
        when "human_escalate" then :warning
        when "stop" then :warning
        else :info
        end

      message =
        case decision
        when "human_escalate"
          "Artifact ##{artifact.id} の draft PR ##{ci_status['pr_number']} は CI 失敗のため人間エスカレーションが必要です"
        when "stop"
          "Artifact ##{artifact.id} の draft PR ##{ci_status['pr_number']} は StopCondition または auto_merge 無効のため停止しました"
        else
          "Artifact ##{artifact.id} の draft PR ##{ci_status['pr_number']} は CI 状態 #{ci_status['status']} で継続可能です"
        end

      create_event(
        artifact: artifact,
        event_type: "draft_pr_ci_#{decision}",
        severity: severity,
        message: message,
        payload: {
          "artifact_id" => artifact.id,
          "pr_number" => ci_status["pr_number"],
          "pr_url" => ci_status["pr_url"],
          "ci_status" => ci_status["status"],
          "ci_conclusion" => ci_status["conclusion"],
          "ci_retry_count" => retry_count,
          "ci_terminal" => terminal,
          "ci_terminal_reason" => terminal_reason,
          "decision" => decision,
          "failed_checks" => ci_status["failed_checks"],
          "head_sha" => ci_status["head_sha"]
        }
      )
    end

    def create_retrying_event(artifact, ci_status, retry_count)
      create_event(
        artifact: artifact,
        event_type: "draft_pr_ci_retrying",
        severity: :info,
        message: "Artifact ##{artifact.id} の draft PR ##{ci_status['pr_number']} は CI pending のため再試行中です（#{retry_count}/#{MAX_PENDING_RETRIES}）",
        payload: {
          "artifact_id" => artifact.id,
          "pr_number" => ci_status["pr_number"],
          "ci_status" => ci_status["status"],
          "retry_count" => retry_count
        }
      )
    end

    def create_terminal_event(artifact, ci_status, decision, terminal_reason, retry_count)
      severity = decision == "continue" ? :info : :warning
      create_event(
        artifact: artifact,
        event_type: "draft_pr_ci_terminal",
        severity: severity,
        message: "Artifact ##{artifact.id} の draft PR ##{ci_status['pr_number']} が terminal に到達しました（decision=#{decision}, reason=#{terminal_reason}）",
        payload: {
          "artifact_id" => artifact.id,
          "pr_number" => ci_status["pr_number"],
          "decision" => decision,
          "terminal_reason" => terminal_reason,
          "retry_count" => retry_count,
          "ci_status" => ci_status["status"],
          "ci_conclusion" => ci_status["conclusion"]
        }
      )
    end

    def create_event(artifact:, event_type:, severity:, message:, payload:)
      Event.create!(
        run: run,
        event_type: event_type,
        severity: severity,
        occurred_at: Time.current,
        message: message,
        payload_json: payload,
        subject_type: "LedgerV2::Artifact",
        subject_id: artifact.id
      )
    end
  end
end
