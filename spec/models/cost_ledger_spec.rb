require "rails_helper"

RSpec.describe CostLedger, type: :model do
  let(:valid_attrs) do
    {
      subject_type: :job,
      subject_id: "job-123",
      scope_level: :service,
      service_id: "ai_sns",
      source: :llm_api,
      amount_jpy: 12.5,
      incurred_at: Time.current
    }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:subject_type) }
    it { is_expected.to validate_presence_of(:subject_id) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_presence_of(:incurred_at) }

    it "requires non-negative amount_jpy" do
      record = described_class.new(valid_attrs.merge(amount_jpy: -1))
      expect(record).not_to be_valid
      expect(record.errors[:amount_jpy]).to be_present
    end

    it "is valid with valid attributes" do
      expect(described_class.new(valid_attrs)).to be_valid
    end
  end

  describe "enums" do
    it "defines subject_type keys" do
      expect(described_class.subject_types.keys)
        .to contain_exactly("meeting", "ticket", "artifact", "job", "service")
    end

    it "defines source keys" do
      expect(described_class.sources.keys)
        .to contain_exactly("llm_api", "vps_runtime", "human_hours", "external_service")
    end
  end

  describe "callbacks" do
    it "defaults recorded_at to current time when blank" do
      record = described_class.new(valid_attrs.merge(recorded_at: nil))
      record.valid?
      expect(record.recorded_at).to be_present
    end
  end

  describe ".total_amount_jpy" do
    it "sums amount_jpy across records" do
      described_class.create!(valid_attrs.merge(amount_jpy: 100))
      described_class.create!(valid_attrs.merge(amount_jpy: 50, subject_id: "job-456"))

      expect(described_class.total_amount_jpy).to eq(150)
    end
  end

  describe ".for_subject" do
    it "filters by subject_type and subject_id" do
      matched = described_class.create!(valid_attrs.merge(subject_id: "target"))
      described_class.create!(valid_attrs.merge(subject_id: "other"))

      expect(described_class.for_subject(:job, "target")).to contain_exactly(matched)
    end
  end
end
