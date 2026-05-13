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
    TRACKED_DRAFT_PR_FIELDS = %w[
      ci_status
      ci_conclusion
      ci_decision
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
      pr_number = artifact.metadata_json.dig("draft_pr", "number")
      return { created_event_count: 0 } if pr_number.blank?

      ci_status = GithubPrService.fetch_ci_status(pr_number: pr_number)
      return sync_failure(artifact, pr_number) if ci_status.blank?

      decision = decision_for(ci_status["status"])
      metadata = build_metadata(artifact, ci_status, decision)
      return { created_event_count: 0 } unless state_changed?(artifact, metadata)

      return { created_event_count: 0 } if dry_run

      artifact.update!(metadata_json: metadata)

      created_event_count = 0
      create_decision_event(artifact, ci_status, decision)
      created_event_count += 1
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

    def build_metadata(artifact, ci_status, decision)
      draft_pr_metadata = artifact.metadata_json.fetch("draft_pr", {}).merge(
        "ci_status" => ci_status["status"],
        "ci_conclusion" => ci_status["conclusion"],
        "ci_decision" => decision,
        "ci_checked_at" => Time.current.iso8601,
        "failed_checks" => ci_status["failed_checks"],
        "head_sha" => ci_status["head_sha"],
        "check_runs" => ci_status["check_runs"]
      )

      merged_metadata(artifact, "draft_pr" => draft_pr_metadata)
    end

    def decision_for(status)
      return "human_escalate" if status == "failure"
      return "stop" unless Flags.enabled?(:auto_merge)

      "continue"
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

    def create_decision_event(artifact, ci_status, decision)
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
          "decision" => decision,
          "failed_checks" => ci_status["failed_checks"],
          "head_sha" => ci_status["head_sha"]
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
