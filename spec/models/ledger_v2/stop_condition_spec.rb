require "rails_helper"

RSpec.describe LedgerV2::StopCondition, type: :model do
  describe "バリデーション" do
    it "必須カラムが揃っていれば有効" do
      condition = described_class.new(
        target_type: "runner",
        target_name: "DailyRunner",
        reason:      "テスト用ブロック",
        severity:    "medium",
        created_by:  "human_admin"
      )
      expect(condition).to be_valid
    end

    it "target_type が未知の値だと無効" do
      condition = described_class.new(
        target_type: "unknown_type",
        reason:      "理由",
        severity:    "low",
        created_by:  "admin"
      )
      expect(condition).not_to be_valid
      expect(condition.errors[:target_type]).to be_present
    end

    it "severity が未知の値だと無効" do
      condition = described_class.new(
        target_type: "runner",
        reason:      "理由",
        severity:    "ultra_critical",
        created_by:  "admin"
      )
      expect(condition).not_to be_valid
      expect(condition.errors[:severity]).to be_present
    end

    it "reason が空だと無効" do
      condition = described_class.new(
        target_type: "runner",
        severity:    "medium",
        created_by:  "admin"
      )
      expect(condition).not_to be_valid
      expect(condition.errors[:reason]).to be_present
    end

    it "created_by が空だと無効" do
      condition = described_class.new(
        target_type: "runner",
        reason:      "理由",
        severity:    "medium"
      )
      expect(condition).not_to be_valid
      expect(condition.errors[:created_by]).to be_present
    end
  end

  describe ".active_conditions" do
    it "active: true かつ expires_at が未来のものを返す" do
      active = described_class.create!(
        target_type: "runner", reason: "有効", severity: "low",
        created_by: "admin", active: true, expires_at: 1.hour.from_now
      )
      expect(described_class.active_conditions).to include(active)
    end

    it "active: false のものは返さない" do
      described_class.create!(
        target_type: "runner", reason: "無効化済み", severity: "low",
        created_by: "admin", active: false
      )
      inactive = described_class.where(active: false).last
      expect(described_class.active_conditions).not_to include(inactive)
    end

    it "expires_at が過去のものは返さない" do
      described_class.create!(
        target_type: "runner", reason: "期限切れ", severity: "low",
        created_by: "admin", active: true, expires_at: 1.hour.ago
      )
      expired = described_class.where("expires_at < ?", Time.current).last
      expect(described_class.active_conditions).not_to include(expired)
    end
  end

  describe ".blocking_runner?" do
    it "target_type: runner かつ target_name が一致する active な条件があれば true" do
      described_class.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "ブロック", severity: "high", created_by: "admin"
      )
      expect(described_class.blocking_runner?("DailyRunner")).to be true
    end

    it "target_type: all の active な条件があればすべての Runner をブロック" do
      described_class.create!(
        target_type: "all",
        reason: "全停止", severity: "critical", created_by: "admin"
      )
      expect(described_class.blocking_runner?("WeeklyRunner")).to be true
    end

    it "target_name が異なれば false" do
      described_class.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "ブロック", severity: "low", created_by: "admin"
      )
      expect(described_class.blocking_runner?("WeeklyRunner")).to be false
    end

    it "active: false の条件は false" do
      described_class.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "解除済み", severity: "low", created_by: "admin", active: false
      )
      expect(described_class.blocking_runner?("DailyRunner")).to be false
    end
  end

  describe ".blocking_feature?" do
    it "target_type がフラグ名と一致する active な条件があれば true" do
      described_class.create!(
        target_type: "auto_merge", reason: "逆戻り", severity: "high", created_by: "admin"
      )
      expect(described_class.blocking_feature?("auto_merge")).to be true
    end

    it "Symbol でも動作する" do
      described_class.create!(
        target_type: "auto_merge", reason: "逆戻り", severity: "high", created_by: "admin"
      )
      expect(described_class.blocking_feature?(:auto_merge)).to be true
    end

    it "target_type: all の active な条件があればすべての機能フラグをブロック" do
      described_class.create!(
        target_type: "all", reason: "全停止", severity: "critical", created_by: "admin"
      )
      expect(described_class.blocking_feature?("auto_merge")).to be true
    end

    it "target_type が異なれば false" do
      described_class.create!(
        target_type: "auto_pr", reason: "auto_pr のみ停止", severity: "low", created_by: "admin"
      )
      expect(described_class.blocking_feature?("auto_merge")).to be false
    end

    it "active: false の条件は false" do
      described_class.create!(
        target_type: "auto_merge", reason: "解除済み", severity: "low",
        created_by: "admin", active: false
      )
      expect(described_class.blocking_feature?("auto_merge")).to be false
    end
  end

  describe "#resolve!" do
    it "active を false にし resolved_by / resolved_at を記録する" do
      condition = described_class.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "一時停止", severity: "medium", created_by: "admin"
      )

      condition.resolve!(resolved_by: "human_operator")

      condition.reload
      expect(condition.active).to       be false
      expect(condition.resolved_by).to  eq("human_operator")
      expect(condition.resolved_at).to  be_within(2.seconds).of(Time.current)
    end

    it "resolved_by が空だと ArgumentError" do
      condition = described_class.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "一時停止", severity: "medium", created_by: "admin"
      )
      expect { condition.resolve!(resolved_by: "") }.to raise_error(ArgumentError)
    end
  end
end
