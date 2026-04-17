require "rails_helper"

RSpec.describe Artifacts::Publisher do
  describe ".publish" do
    it "creates a v1 published artifact when none exist" do
      result = described_class.publish(
        artifact_type: :kpi_definition,
        title: "AI SNS KPI 定義書",
        scope_level: :service,
        service_id: "ai_sns",
        content: { kpis: [ "wau" ] },
        author: "business_owner"
      )

      expect(result.artifact).to be_persisted
      expect(result.artifact.artifact_version).to eq(1)
      expect(result.artifact).to be_status_published
      expect(result.artifact.published_at).to be_present
      expect(result.previous).to be_nil
      expect(result.superseded?).to be(false)
    end

    it "creates a v2 and supersedes v1 when a prior version exists" do
      v1 = create(:artifact_ledger,
                  artifact_type: :spec,
                  title: "仕様書 A",
                  scope_level: :service,
                  service_id: "ai_sns",
                  artifact_version: 1,
                  status: :published)

      result = described_class.publish(
        artifact_type: :spec,
        title: "仕様書 A",
        scope_level: :service,
        service_id: "ai_sns",
        content: { version: "v2" }
      )

      expect(result.artifact.artifact_version).to eq(2)
      expect(result.artifact.supersedes).to eq(v1)
      expect(result.previous).to eq(v1)
      expect(result.superseded?).to be(true)
      expect(v1.reload).to be_status_superseded
    end

    it "rolls back v1→superseded when new version creation fails" do
      create(:artifact_ledger,
             artifact_type: :spec,
             title: "固定タイトル",
             artifact_version: 1,
             status: :published)

      allow(ArtifactLedger).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(ArtifactLedger.new))

      expect do
        described_class.publish(
          artifact_type: :spec,
          title: "固定タイトル",
          scope_level: :service,
          service_id: "ai_sns",
          content: {}
        )
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(ArtifactLedger.where(artifact_type: :spec, title: "固定タイトル").first).to be_status_published
    end

    it "supports third version chain (v1 → v2 → v3)" do
      described_class.publish(
        artifact_type: :tech_record, title: "Runbook", scope_level: :company, content: {}
      )
      described_class.publish(
        artifact_type: :tech_record, title: "Runbook", scope_level: :company, content: {}
      )
      result = described_class.publish(
        artifact_type: :tech_record, title: "Runbook", scope_level: :company, content: {}
      )

      expect(result.artifact.artifact_version).to eq(3)
      expect(ArtifactLedger.where(artifact_type: :tech_record, title: "Runbook").status_published.count).to eq(1)
      expect(ArtifactLedger.where(artifact_type: :tech_record, title: "Runbook").status_superseded.count).to eq(2)
    end
  end
end
