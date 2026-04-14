require "rails_helper"

RSpec.describe "Admin::AiSns", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_PASSWORD").and_return(nil)
  end

  describe "GET /admin/ai_sns" do
    it "実行履歴と予定タスクのセクションが表示される" do
      get "/admin/ai_sns"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AI SNS Scheduled Tasks")
      expect(response.body).to include("Upcoming Scheduled Jobs")
      expect(response.body).to include("Recent AI SNS Job Executions")
    end
  end

  describe "POST /admin/ai_sns/run_job" do
    it "手動実行後に ActiveJob ID 付き通知と直近実行ステータスを表示する" do
      fake_job = instance_double(AiActionCheckJob, job_id: "manual-job-123")
      allow(AiActionCheckJob).to receive(:perform_later).with("like").and_return(fake_job)

      post "/admin/ai_sns/run_job", params: { job: "ai_action_like" }

      expect(response).to redirect_to("/admin/ai_sns")
      follow_redirect!

      expect(response.body).to include("AiActionCheckJob をキューに追加しました（ActiveJob ID: manual-job-123）")
      expect(response.body).to include("Last Manual Job Status")
      expect(response.body).to include("manual-job-123")
    end

    it "一時的な UnknownJobClassError は手動ジョブステータス表示時に自動discardされる" do
      fake_job = instance_double(AiActionCheckJob, job_id: "manual-job-unknown-1")
      allow(AiActionCheckJob).to receive(:perform_later).with("like").and_return(fake_job)

      post "/admin/ai_sns/run_job", params: { job: "ai_action_like" }

      job = SolidQueue::Job.create!(
        queue_name: "default",
        class_name: "ActiveJob::QueueAdapters::SolidQueueAdapter::JobWrapper",
        arguments: [ { job_class: "AiActionCheckJob" } ].to_json,
        priority: 0,
        active_job_id: "manual-job-unknown-1"
      )
      failed_execution = SolidQueue::FailedExecution.create!(
        job: job,
        error: {
          exception_class: "ActiveJob::UnknownJobClassError",
          message: "Failed to instantiate job, class `AiActionCheckJob` doesn't exist"
        }.to_json
      )

      get "/admin/ai_sns"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Last Manual Job Status")
      expect(response.body).not_to include("Failed to instantiate job, class `AiActionCheckJob` doesn't exist")

      active_failure_scope = SolidQueue::FailedExecution.where(id: failed_execution.id)
      if SolidQueue::FailedExecution.column_names.include?("discarded_at")
        active_failure_scope = active_failure_scope.where(discarded_at: nil)
      end
      expect(active_failure_scope).to be_empty
    end
  end

  describe "POST /admin/ai_sns/trigger_ai_sns_plan" do
    it "DEPLOY_TOKEN が未設定ならアラートを表示する" do
      allow(ENV).to receive(:[]).with("DEPLOY_TOKEN").and_return(nil)

      post "/admin/trigger_ai_sns_plan"

      expect(response).to redirect_to("/admin/ai_sns")
      follow_redirect!
      expect(response.body).to include("DEPLOY_TOKEN が設定されていません")
    end
  end
end
