require "rails_helper"

RSpec.describe KpiLedger, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:kpi_key) }
    it { is_expected.to validate_presence_of(:scope_level) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:status) }

    it "validates uniqueness of kpi_key" do
      described_class.create!(kpi_key: "kpi:ai_sns_wau", scope_level: :service, service_id: "ai_sns", name: "WAU", status: :active)
      duplicate = described_class.new(kpi_key: "kpi:ai_sns_wau", scope_level: :service, service_id: "ai_sns", name: "WAU duplicate", status: :active)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:kpi_key]).to include("has already been taken")
    end
  end

  describe "enums" do
    it "defines scope_level enum" do
      expect(described_class.scope_levels.keys).to contain_exactly("company", "portfolio", "service", "cross_service")
    end

    it "defines grade enum with healthy/warning/critical (Phase 34)" do
      expect(described_class.grades.keys).to contain_exactly("healthy", "warning", "critical")
    end
  end

  describe "#evaluate_grade (Phase 34)" do
    context "higher_better direction (default)" do
      let(:thresholds) { { "healthy" => 100, "warning" => 50 } }

      it "returns healthy when value >= healthy threshold" do
        kpi = create(:kpi_ledger, current_value: { "value" => 150 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("healthy")
      end

      it "returns warning when warning <= value < healthy" do
        kpi = create(:kpi_ledger, current_value: { "value" => 80 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("warning")
      end

      it "returns critical when value < warning threshold" do
        kpi = create(:kpi_ledger, current_value: { "value" => 20 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("critical")
      end
    end

    context "lower_better direction" do
      let(:thresholds) { { "healthy" => 10, "warning" => 50, "direction" => "lower_better" } }

      it "returns healthy when value <= healthy threshold" do
        kpi = create(:kpi_ledger, current_value: { "value" => 5 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("healthy")
      end

      it "returns warning when healthy < value <= warning" do
        kpi = create(:kpi_ledger, current_value: { "value" => 30 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("warning")
      end

      it "returns critical when value > warning threshold" do
        kpi = create(:kpi_ledger, current_value: { "value" => 100 }, thresholds:)
        expect(kpi.evaluate_grade).to eq("critical")
      end
    end

    it "returns nil when current_value is missing" do
      kpi = create(:kpi_ledger, current_value: {}, thresholds: { "healthy" => 1, "warning" => 0 })
      expect(kpi.evaluate_grade).to be_nil
    end

    it "returns nil when thresholds are missing" do
      kpi = create(:kpi_ledger, current_value: { "value" => 100 }, thresholds: {})
      expect(kpi.evaluate_grade).to be_nil
    end

    it "rejects invalid direction via validation" do
      kpi = build(:kpi_ledger, thresholds: { "healthy" => 1, "warning" => 0, "direction" => "invalid" })
      expect(kpi).not_to be_valid
      expect(kpi.errors[:thresholds]).to include(/direction must be/)
    end
  end

  describe "#apply_grade! (Phase 34)" do
    it "persists grade and graded_at" do
      kpi = create(:kpi_ledger, current_value: { "value" => 150 }, thresholds: { "healthy" => 100, "warning" => 50 })
      # after_save callback により create 時点で grade=healthy が計算されている。
      expect(kpi.reload.grade).to eq("healthy")

      # grade を手動で nil にリセットしてから apply_grade! が正しく復元することを確認する。
      kpi.update_column(:grade, nil)
      kpi.update_column(:graded_at, nil)
      expect(kpi.reload.grade).to be_nil

      kpi.apply_grade!

      expect(kpi.reload.grade).to eq("healthy")
      expect(kpi.reload.graded_at).to be_present
    end

    it "returns nil without side effects when grade cannot be evaluated" do
      kpi = create(:kpi_ledger, current_value: {}, thresholds: {})

      expect(kpi.apply_grade!).to be_nil
      expect(kpi.reload.grade).to be_nil
    end
  end

  describe "after_save: auto grade recalculation on current_value change" do
    let(:thresholds) { { "healthy" => 100, "warning" => 50 } }

    it "updates grade automatically when current_value is written" do
      kpi = create(:kpi_ledger, thresholds:, current_value: {})
      expect(kpi.reload.grade).to be_nil

      kpi.update!(current_value: { "value" => 200 })

      expect(kpi.reload.grade).to eq("healthy")
    end

    it "transitions grade from healthy to critical when value drops" do
      kpi = create(:kpi_ledger, thresholds:, current_value: { "value" => 200 })
      expect(kpi.reload.grade).to eq("healthy")

      kpi.update!(current_value: { "value" => 10 })

      expect(kpi.reload.grade).to eq("critical")
    end

    it "does not trigger grade change when other attributes change" do
      kpi = create(:kpi_ledger, thresholds:, current_value: { "value" => 200 })
      original_graded_at = kpi.reload.graded_at

      kpi.update!(name: "Updated Name")

      expect(kpi.reload.graded_at).to eq(original_graded_at)
    end

    it "skips auto recalculation when thresholds are missing" do
      kpi = create(:kpi_ledger, thresholds: {}, current_value: {})
      kpi.update!(current_value: { "value" => 999 })
      expect(kpi.reload.grade).to be_nil
    end
  end
end
