require "rails_helper"

RSpec.describe ArtifactLedger, "supersedes self-reference protection" do
  it "rejects supersedes_id pointing to self" do
    artifact = create(:artifact_ledger, artifact_type: :kpi_definition, title: "X", artifact_version: 1)
    artifact.supersedes_id = artifact.id
    expect(artifact).not_to be_valid
    expect(artifact.errors[:supersedes_id]).to include("must not reference self")
  end
end
