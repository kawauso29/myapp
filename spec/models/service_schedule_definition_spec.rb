require "rails_helper"

RSpec.describe ServiceScheduleDefinition, type: :model do
  describe "validations" do
    subject(:definition) do
      described_class.new(
        job_key: "daily_ledger_run:test_svc",
        job_class: "DailyLedgerRunJob",
        cron: "*/30 * * * *",
        queue: "default",
        service_id: "test_svc",
        cadence: :daily,
        args: ["test_svc"]
      )
    end

    it { is_expected.to be_valid }

    it "requires job_key" do
      definition.job_key = nil
      expect(definition).not_to be_valid
    end

    it "requires job_class" do
      definition.job_class = nil
      expect(definition).not_to be_valid
    end

    it "requires cron" do
      definition.cron = nil
      expect(definition).not_to be_valid
    end

    it "validates job_class format" do
      definition.job_class = "invalid class"
      expect(definition).not_to be_valid
      expect(definition.errors[:job_class]).to be_present
    end

    it "validates cron format (5-field)" do
      definition.cron = "invalid"
      expect(definition).not_to be_valid
      expect(definition.errors[:cron]).to be_present
    end

    it "enforces uniqueness of job_key" do
      described_class.create!(job_key: "unique_key", job_class: "TestJob", cron: "* * * * *")
      duplicate = described_class.new(job_key: "unique_key", job_class: "TestJob", cron: "* * * * *")
      expect(duplicate).not_to be_valid
    end
  end

  describe ".active" do
    it "returns only enabled definitions" do
      active = described_class.create!(job_key: "active_job", job_class: "TestJob", cron: "* * * * *", enabled: true)
      described_class.create!(job_key: "inactive_job", job_class: "TestJob2", cron: "* * * * *", enabled: false)
      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe "#job_klass" do
    it "returns the constantized class when valid" do
      definition = described_class.new(job_class: "String")
      expect(definition.job_klass).to eq(String)
    end

    it "returns nil when class does not exist" do
      definition = described_class.new(job_class: "NonExistentJob")
      expect(definition.job_klass).to be_nil
    end
  end
end
