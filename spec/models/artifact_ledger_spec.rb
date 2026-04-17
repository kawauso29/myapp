require "rails_helper"

RSpec.describe ArtifactLedger, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      expect(build(:artifact_ledger)).to be_valid
    end

    it "requires artifact_type / scope_level / title" do
      record = ArtifactLedger.new
      record.valid?
      expect(record.errors.attribute_names).to include(:artifact_type, :scope_level, :title)
    end

    it "rejects artifact_version < 1" do
      record = build(:artifact_ledger, artifact_version: 0)
      expect(record).not_to be_valid
    end

    it "rejects supersedes with mismatched artifact_type" do
      previous = create(:artifact_ledger, artifact_type: :spec, title: "Same Title")
      record = build(:artifact_ledger,
                     artifact_type: :execution_plan,
                     title: "Same Title",
                     artifact_version: 2,
                     supersedes: previous)
      expect(record).not_to be_valid
      expect(record.errors[:artifact_type]).to include("must match superseded version")
    end

    it "rejects supersedes with non-consecutive artifact_version" do
      previous = create(:artifact_ledger, artifact_type: :spec, title: "Title A", artifact_version: 1)
      record = build(:artifact_ledger,
                     artifact_type: :spec,
                     title: "Title A",
                     artifact_version: 3,
                     supersedes: previous)
      expect(record).not_to be_valid
      expect(record.errors[:artifact_version]).to include("must be superseded version + 1")
    end
  end

  describe "enums" do
    it "defines the 6 artifact types from §16" do
      expect(described_class.artifact_types.keys).to contain_exactly(
        "kpi_definition", "spec", "execution_plan",
        "audit_judgment", "customer_notice", "tech_record"
      )
    end

    it "defines lifecycle statuses including superseded" do
      expect(described_class.statuses.keys).to contain_exactly(
        "draft", "published", "superseded", "archived"
      )
    end
  end

  describe "uniqueness of (artifact_type, title, artifact_version)" do
    it "disallows duplicate versions of the same artifact" do
      create(:artifact_ledger, artifact_type: :spec, title: "Unique Title", artifact_version: 1)
      duplicate = build(:artifact_ledger, artifact_type: :spec, title: "Unique Title", artifact_version: 1)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
