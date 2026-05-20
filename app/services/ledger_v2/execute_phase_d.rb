# LedgerV2::ExecutePhaseD — PhaseDGate の判定を実際の merge 実行経路へ接続する。
#
# 責務:
# - draft PR が terminal(ci_passed) の Artifact に対して PhaseDGate を評価する
# - このリポジトリでは main への merge が CI→deploy に直結するため、
#   deploy_allowed=true のときだけ GitHub merge API を叩く
# - 判定結果と実行結果を Artifact metadata_json["phase_d"] と Event に記録する
module LedgerV2
  class ExecutePhaseD
    # 初回実行を含む merge 試行総数の上限。
    # 例: 3 の場合、3 回目の失敗で human_escalate へ終端化する。
    MAX_MERGE_RETRIES = 3

    Result = Struct.new(:created_event_count, keyword_init: true) do
      def initialize(**)
        super
        self.created_event_count ||= 0
      end
    end

    def self.call(run:, artifact:, dry_run: false)
      new(run: run, artifact: artifact, dry_run: dry_run).call
    end

    def initialize(run:, artifact:, dry_run:)
      @run = run
      @artifact = artifact
      @dry_run = dry_run
    end

    def call
      return Result.new unless eligible_artifact?
      return Result.new if terminal?

      gate = PhaseDGate.call(artifact: artifact)
      return record_blocked(gate) unless gate.deploy_allowed

      execute_merge(gate)
    end

    private

    attr_reader :run, :artifact, :dry_run

    def eligible_artifact?
      artifact.artifact_type == "ci_fix_suggestion" &&
        artifact.review_status_accepted? &&
        draft_pr["number"].present? &&
        draft_pr["head_sha"].present? &&
        draft_pr["ci_terminal"] == true &&
        draft_pr["ci_terminal_reason"] == "ci_passed"
    end

    def execute_merge(gate)
      current_phase_d = phase_d_payload(gate)
      merge_result = GithubPrService.merge_pr(
        pr_number: draft_pr.fetch("number"),
        sha: draft_pr.fetch("head_sha"),
        commit_title: "ledger-v2: merge Artifact ##{artifact.id}"
      )

      if merge_result&.dig("merged")
        record_result(
          event_type: "phase_d_pr_merged",
          severity: :info,
          message: "Artifact ##{artifact.id} の draft PR ##{draft_pr.fetch('number')} を Phase D で merge しました",
          phase_d_payload: current_phase_d.merge(
            "execution_status" => "merged",
            "merge_retry_count" => current_retry_count,
            "merge_terminal" => true,
            "merge_terminal_reason" => "merged",
            "merged_at" => Time.current.iso8601,
            "merge_commit_sha" => merge_result["sha"],
            "merge_error" => nil
          ),
          event_payload: {
            "artifact_id" => artifact.id,
            "pr_number" => draft_pr.fetch("number"),
            "merge_retry_count" => current_retry_count,
            "merge_commit_sha" => merge_result["sha"],
            "merge_message" => merge_result["message"]
          }
        )
      else
        reason = merge_result&.dig("message").presence || "GitHub PR merge failed"
        record_failed_result(current_phase_d, reason)
      end
    end

    def record_blocked(gate)
      record_result(
        event_type: "phase_d_execution_blocked",
        severity: :info,
        message: "Artifact ##{artifact.id} の Phase D 実行は保留です（#{gate.deploy_block_reasons.join(', ')}）",
        phase_d_payload: phase_d_payload(gate).merge(
          "execution_status" => "blocked",
          "merge_terminal" => false,
          "merge_terminal_reason" => nil,
          "merged_at" => nil,
          "merge_commit_sha" => nil,
          "merge_error" => nil
        ),
        event_payload: {
          "artifact_id" => artifact.id,
          "pr_number" => draft_pr["number"],
          "deploy_block_reasons" => gate.deploy_block_reasons,
          "merge_block_reasons" => gate.merge_block_reasons
        }
      )
    end

    def record_result(event_type:, severity:, message:, phase_d_payload:, event_payload:)
      return Result.new if dry_run
      return Result.new unless phase_d_changed?(phase_d_payload)

      artifact.update!(metadata_json: merged_metadata("phase_d" => phase_d_payload))
      create_event(event_type:, severity:, message:, payload: event_payload.merge(phase_d_payload))
      Result.new(created_event_count: 1)
    end

    def phase_d_payload(gate)
      {
        "merge_allowed" => gate.merge_allowed,
        "deploy_allowed" => gate.deploy_allowed,
        "merge_retry_count" => current_retry_count,
        "merge_block_reasons" => gate.merge_block_reasons,
        "deploy_block_reasons" => gate.deploy_block_reasons,
        "checked_at" => Time.current.iso8601
      }
    end

    def phase_d_changed?(next_phase_d)
      current_phase_d = artifact.metadata_json.fetch("phase_d", {})
      comparable_current = current_phase_d.except("checked_at")
      comparable_next = next_phase_d.except("checked_at")
      comparable_current != comparable_next
    end

    def terminal?
      %w[merged human_escalate].include?(artifact.metadata_json.fetch("phase_d", {}).fetch("execution_status", nil))
    end

    def current_retry_count
      artifact.metadata_json.fetch("phase_d", {}).fetch("merge_retry_count", 0).to_i
    end

    def record_failed_result(current_phase_d, reason)
      retry_count = current_retry_count + 1
      retry_exhausted = retry_count >= MAX_MERGE_RETRIES

      if retry_exhausted
        record_result(
          event_type: "phase_d_merge_human_escalate",
          severity: :warning,
          message: "Artifact ##{artifact.id} の draft PR ##{draft_pr.fetch('number')} は Phase D merge 失敗が上限に達したため人間エスカレーションします: #{reason}",
          phase_d_payload: current_phase_d.merge(
            "execution_status" => "human_escalate",
            "merge_retry_count" => retry_count,
            "merge_terminal" => true,
            "merge_terminal_reason" => "merge_failed_retry_exhausted",
            "merge_escalated_at" => Time.current.iso8601,
            "merged_at" => nil,
            "merge_commit_sha" => nil,
            "merge_error" => reason
          ),
          event_payload: {
            "artifact_id" => artifact.id,
            "pr_number" => draft_pr.fetch("number"),
            "merge_retry_count" => retry_count,
            "merge_retry_limit" => MAX_MERGE_RETRIES,
            "merge_error" => reason
          }
        )
      else
        record_result(
          event_type: "phase_d_merge_retrying",
          severity: :warning,
          message: "Artifact ##{artifact.id} の draft PR ##{draft_pr.fetch('number')} の Phase D merge に失敗したため再試行します（#{retry_count}/#{MAX_MERGE_RETRIES}）: #{reason}",
          phase_d_payload: current_phase_d.merge(
            "execution_status" => "retrying",
            "merge_retry_count" => retry_count,
            "merge_terminal" => false,
            "merge_terminal_reason" => nil,
            "merge_escalated_at" => nil,
            "merged_at" => nil,
            "merge_commit_sha" => nil,
            "merge_error" => reason
          ),
          event_payload: {
            "artifact_id" => artifact.id,
            "pr_number" => draft_pr.fetch("number"),
            "merge_retry_count" => retry_count,
            "merge_retry_limit" => MAX_MERGE_RETRIES,
            "merge_error" => reason
          }
        )
      end
    end

    def merged_metadata(extra)
      (artifact.metadata_json || {}).merge(extra)
    end

    def draft_pr
      artifact.metadata_json.fetch("draft_pr", {})
    end

    def create_event(event_type:, severity:, message:, payload:)
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
