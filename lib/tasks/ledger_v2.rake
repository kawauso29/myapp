namespace :ledger_v2 do
  desc "Record Phase D deploy / rollback result into Ledger V2 artifact metadata and events"
  task record_phase_d_deploy: :environment do
    LedgerV2::RecordPhaseDDeploy.call(
      commit_sha: ENV.fetch("COMMIT_SHA"),
      deploy_status: ENV.fetch("DEPLOY_STATUS"),
      rollback_status: ENV["ROLLBACK_STATUS"].presence,
      rollback_target_sha: ENV["ROLLBACK_TARGET_SHA"],
      failed_stage: ENV["FAILED_STAGE"],
      workflow_run_id: ENV["WORKFLOW_RUN_ID"],
      workflow_url: ENV["WORKFLOW_URL"],
      deploy_reason: ENV["DEPLOY_REASON"],
      actor: ENV["ACTOR"]
    )
  end
end
