require "rails_helper"

RSpec.describe LedgerV2::HealthSnapshot, type: :model do
  def valid_attrs(overrides = {})
    {
      period:                            :daily,
      measured_at:                       Time.current,
      ticket_noise_rate:                 0.2,
      artifact_acceptance_rate:          0.8,
      runner_failure_rate:               0.05,
      unresolved_ticket_age_avg:         12.5,
      human_intervention_rate:           0.1,
      kpi_improvement_after_ticket_rate: 0.6,
      stop_trigger_count:                0,
      duplicate_prevented_count:         3,
      pending_review_count:              2,
      open_ticket_count:                 5
    }.merge(overrides)
  end

  describe "create（基本保存）" do
    it "必須カラムが揃っていれば保存できる" do
      snapshot = described_class.new(valid_attrs)
      expect(snapshot.save).to be true
    end

    it "metadata_json を保存できる" do
      snapshot = described_class.create!(valid_attrs(metadata_json: { "note" => "test" }))
      expect(snapshot.metadata_json["note"]).to eq("test")
    end
  end

  describe "バリデーション" do
    it "measured_at が空だと無効" do
      snapshot = described_class.new(valid_attrs(measured_at: nil))
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:measured_at]).to be_present
    end

    it "ticket_noise_rate が 0.0〜1.0 の範囲外（負）だと無効" do
      snapshot = described_class.new(valid_attrs(ticket_noise_rate: -0.1))
      expect(snapshot).not_to be_valid
    end

    it "artifact_acceptance_rate が 1.0 超だと無効" do
      snapshot = described_class.new(valid_attrs(artifact_acceptance_rate: 1.1))
      expect(snapshot).not_to be_valid
    end

    it "runner_failure_rate が負だと無効" do
      snapshot = described_class.new(valid_attrs(runner_failure_rate: -0.5))
      expect(snapshot).not_to be_valid
    end

    it "unresolved_ticket_age_avg が負だと無効" do
      snapshot = described_class.new(valid_attrs(unresolved_ticket_age_avg: -1.0))
      expect(snapshot).not_to be_valid
    end

    it "stop_trigger_count が負だと無効" do
      snapshot = described_class.new(valid_attrs(stop_trigger_count: -1))
      expect(snapshot).not_to be_valid
    end

    it "open_ticket_count が負だと無効" do
      snapshot = described_class.new(valid_attrs(open_ticket_count: -1))
      expect(snapshot).not_to be_valid
    end
  end

  describe "enum（period）" do
    it "daily で保存できる" do
      snapshot = described_class.create!(valid_attrs(period: :daily))
      expect(snapshot.period_daily?).to be true
    end

    it "weekly で保存できる" do
      snapshot = described_class.create!(valid_attrs(period: :weekly))
      expect(snapshot.period_weekly?).to be true
    end

    it "prefix つき述語メソッドが存在する" do
      snapshot = described_class.create!(valid_attrs)
      expect(snapshot).to respond_to(:period_daily?)
      expect(snapshot).not_to respond_to(:daily?)
    end
  end
end
