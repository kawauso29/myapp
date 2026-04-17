require "rails_helper"

RSpec.describe ExperimentLedger do
  describe "validations" do
    it "is valid with valid attributes" do
      experiment = build(:experiment_ledger)
      expect(experiment).to be_valid
    end

    it "requires hypothesis" do
      experiment = build(:experiment_ledger, hypothesis: nil)
      expect(experiment).not_to be_valid
    end

    it "requires kpi_targets to not be blank" do
      experiment = build(:experiment_ledger, kpi_targets: [])
      expect(experiment).not_to be_valid
    end
  end

  describe "#decide!" do
    it "updates status and records decision metadata" do
      experiment = create(:experiment_ledger)
      experiment.decide!(:continued, reason: "KPI target met")

      expect(experiment.reload).to be_status_continued
      expect(experiment.auto_decision).to eq("continued")
      expect(experiment.decided_at).to be_present
      expect(experiment.decision_reason).to eq("KPI target met")
    end
  end

  describe "#expired?" do
    it "returns true for active experiment past deadline" do
      experiment = create(:experiment_ledger, deadline: 1.day.ago.to_date)
      expect(experiment).to be_expired
    end

    it "returns false for active experiment before deadline" do
      experiment = create(:experiment_ledger, deadline: 30.days.from_now.to_date)
      expect(experiment).not_to be_expired
    end
  end

  describe "scopes" do
    it "active_experiments returns only active and not expired" do
      create(:experiment_ledger, deadline: 30.days.from_now.to_date)
      create(:experiment_ledger, deadline: 1.day.ago.to_date)
      create(:experiment_ledger, deadline: 30.days.from_now.to_date, status: :withdrawn)

      expect(ExperimentLedger.active_experiments.count).to eq(1)
    end

    it "expired_candidates returns active experiments past deadline" do
      create(:experiment_ledger, deadline: 1.day.ago.to_date)
      create(:experiment_ledger, deadline: 30.days.from_now.to_date)

      expect(ExperimentLedger.expired_candidates.count).to eq(1)
    end
  end
end
