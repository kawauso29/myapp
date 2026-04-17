require "rails_helper"

RSpec.describe Ledgers::RunnerArtifactPublisher do
  describe ".publish_for!" do
    let(:service_id) { "ai_sns" }
    let!(:weekly_definition) do
      create(:meeting_definition,
             meeting_key: "weekly_dept",
             meeting_type: :weekly,
             scope_level: :service,
             service_id: service_id)
    end

    let(:meeting) do
      MeetingLedger.create!(
        meeting_definition: weekly_definition,
        meeting_key: weekly_definition.meeting_key,
        meeting_type: weekly_definition.meeting_type,
        scope_level: weekly_definition.scope_level,
        service_id: service_id,
        chair: weekly_definition.chair_role,
        participants: [ "planning" ],
        role_fill_rate: 1.0,
        held_at: Time.current,
        status: :closed,
        decisions: [ { ticket_id: 1, result: "approved" } ],
        idempotency_key: "weekly_dept:ai_sns:2026w16"
      )
    end

    it "publishes an execution_plan artifact with meeting-derived content" do
      result = described_class.publish_for!(meeting: meeting, runner: :weekly_dept, service_id: service_id)

      expect(result).not_to be_nil
      artifact = result.artifact
      expect(artifact.artifact_type).to eq("execution_plan")
      expect(artifact.scope_level).to eq("service")
      expect(artifact.service_id).to eq(service_id)
      expect(artifact.title).to eq("Weekly Dept Minutes Summary (ai_sns)")
      expect(artifact.source_meeting).to eq(meeting)
      expect(artifact.content["decisions"]).to eq([ { "ticket_id" => 1, "result" => "approved" } ])
      expect(artifact.idempotency_key).to eq("artifact:weekly_dept:#{meeting.idempotency_key}")
      expect(artifact).to be_status_published
    end

    it "supersedes the previous version when publishing the same meeting twice" do
      first = described_class.publish_for!(meeting: meeting, runner: :weekly_dept, service_id: service_id)
      # 冪等キーを外して再パブリッシュできるように nil 化する（同じ meeting を 2 回呼ぶケースは idempotency で弾かれる）
      first.artifact.update!(idempotency_key: nil)

      second = described_class.publish_for!(meeting: meeting, runner: :weekly_dept, service_id: service_id)

      expect(second).not_to be_nil
      expect(second.superseded?).to be true
      expect(second.artifact.artifact_version).to eq(2)
      expect(first.artifact.reload).to be_status_superseded
    end

    it "returns nil and logs warning when idempotency_key conflicts" do
      described_class.publish_for!(meeting: meeting, runner: :weekly_dept, service_id: service_id)

      expect(Rails.logger).to receive(:warn).with(a_string_including("skipped publish"))

      result = described_class.publish_for!(meeting: meeting, runner: :weekly_dept, service_id: service_id)
      expect(result).to be_nil
    end

    it "uses company scope for company-level runners" do
      company_definition = create(:meeting_definition,
                                  meeting_key: "monthly_ops",
                                  meeting_type: :monthly,
                                  scope_level: :company)
      company_meeting = MeetingLedger.create!(
        meeting_definition: company_definition,
        meeting_key: company_definition.meeting_key,
        meeting_type: company_definition.meeting_type,
        scope_level: company_definition.scope_level,
        chair: company_definition.chair_role,
        participants: [ "ops" ],
        role_fill_rate: 1.0,
        held_at: Time.current,
        status: :closed,
        idempotency_key: "monthly_ops:2026-04"
      )

      result = described_class.publish_for!(meeting: company_meeting, runner: :monthly_ops)

      expect(result.artifact.scope_level).to eq("company")
      expect(result.artifact.service_id).to be_nil
      expect(result.artifact.title).to eq("Monthly Ops Minutes Summary")
    end
  end
end
