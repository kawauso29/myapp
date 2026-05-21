module LedgerV2
  class RecordPhaseDDeploy
    Result = Struct.new(:created_event_count, keyword_init: true) do
      def initialize(**)
        super
        self.created_event_count ||= 0
      end
    end

    def self.call(commit_sha:, deploy_status:, rollback_status: nil, rollback_target_sha: nil,
      failed_stage: nil, workflow_run_id: nil, workflow_url: nil, deploy_reason: nil,
      actor: nil, dry_run: false)
      new(
        commit_sha: commit_sha,
        deploy_status: deploy_status,
        rollback_status: rollback_status,
        rollback_target_sha: rollback_target_sha,
        failed_stage: failed_stage,
        workflow_run_id: workflow_run_id,
        workflow_url: workflow_url,
        deploy_reason: deploy_reason,
        actor: actor,
        dry_run: dry_run
      ).call
    end

    def initialize(commit_sha:, deploy_status:, rollback_status:, rollback_target_sha:, failed_stage:,
      workflow_run_id:, workflow_url:, deploy_reason:, actor:, dry_run:)
      @commit_sha = commit_sha
      @deploy_status = deploy_status
      @rollback_status = rollback_status
      @rollback_target_sha = rollback_target_sha
      @failed_stage = failed_stage
      @workflow_run_id = workflow_run_id
      @workflow_url = workflow_url
      @deploy_reason = deploy_reason
      @actor = actor
      @dry_run = dry_run
    end

    def call
      return Result.new if artifact.blank?
      return Result.new unless state_changed?
      return Result.new if dry_run

      artifact.update!(metadata_json: merged_metadata("phase_d" => next_phase_d))

      created_event_count = create_deploy_event
      created_event_count += create_rollback_event
      Result.new(created_event_count: created_event_count)
    end

    private

    attr_reader :commit_sha, :deploy_status, :rollback_status, :rollback_target_sha, :failed_stage,
      :workflow_run_id, :workflow_url, :deploy_reason, :actor, :dry_run

    def artifact
      @artifact ||= Artifact.where(artifact_type: "ci_fix_suggestion")
                           .where("metadata_json -> 'phase_d' ->> 'execution_status' = ?", "merged")
                           .where("metadata_json -> 'phase_d' ->> 'merge_commit_sha' = ?", commit_sha)
                           .order(updated_at: :desc)
                           .first
    end

    def current_phase_d
      artifact.metadata_json.fetch("phase_d", {})
    end

    def next_phase_d
      current_phase_d.merge(
        "deployment" => deployment_payload
      )
    end

    def deployment_payload
      current_deployment = current_phase_d.fetch("deployment", {})
      current_rollback = current_deployment.fetch("rollback", {})

      current_deployment.merge(
        "commit_sha" => commit_sha,
        "status" => deploy_status,
        "failed_stage" => failed_stage,
        "workflow_run_id" => workflow_run_id,
        "workflow_url" => workflow_url,
        "reason" => deploy_reason,
        "actor" => actor,
        "recorded_at" => Time.current.iso8601,
        "rollback" => rollback_payload(current_rollback)
      ).compact
    end

    def rollback_payload(current_rollback)
      return current_rollback if rollback_status.blank?

      current_rollback.merge(
        "status" => rollback_status,
        "target_sha" => rollback_target_sha,
        "recorded_at" => Time.current.iso8601
      ).compact
    end

    def state_changed?
      comparable_phase_d(current_phase_d) != comparable_phase_d(next_phase_d)
    end

    def comparable_phase_d(payload)
      normalized = payload.deep_dup
      normalized.delete("checked_at")

      deployment = normalized["deployment"]
      return normalized unless deployment.is_a?(Hash)

      deployment.delete("recorded_at")
      rollback = deployment["rollback"]
      rollback.delete("recorded_at") if rollback.is_a?(Hash)
      normalized
    end

    def merged_metadata(extra)
      (artifact.metadata_json || {}).merge(extra)
    end

    def create_deploy_event
      event_type = deploy_status == "succeeded" ? "phase_d_deploy_succeeded" : "phase_d_deploy_failed"
      severity = deploy_status == "succeeded" ? :info : :error
      message =
        if deploy_status == "succeeded"
          "Artifact ##{artifact.id} 由来の Phase D deploy（#{commit_sha}）が成功しました"
        else
          "Artifact ##{artifact.id} 由来の Phase D deploy（#{commit_sha}）が失敗しました"
        end

      create_event(
        event_type: event_type,
        severity: severity,
        message: message,
        payload: deployment_payload.except("rollback").merge(
          "artifact_id" => artifact.id
        )
      )
      1
    end

    def create_rollback_event
      return 0 if rollback_status.blank?

      event_type = rollback_status == "succeeded" ? "phase_d_rollback_succeeded" : "phase_d_rollback_failed"
      severity = rollback_status == "succeeded" ? :warning : :error
      message =
        if rollback_status == "succeeded"
          "Artifact ##{artifact.id} 由来の Phase D deploy 失敗後 rollback（#{rollback_target_sha}）が成功しました"
        else
          "Artifact ##{artifact.id} 由来の Phase D deploy 失敗後 rollback（#{rollback_target_sha}）が失敗しました"
        end

      create_event(
        event_type: event_type,
        severity: severity,
        message: message,
        payload: deployment_payload.fetch("rollback").merge(
          "artifact_id" => artifact.id,
          "commit_sha" => commit_sha
        )
      )
      1
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

    def run
      @run ||= Run.create!(
        runner_name: "RecordPhaseDDeploy",
        trigger_type: :system
      )
    end
  end
end
