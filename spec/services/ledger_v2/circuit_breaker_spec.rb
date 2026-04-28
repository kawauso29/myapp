require "rails_helper"

RSpec.describe LedgerV2::CircuitBreaker, type: :service do
  describe ".blocked?" do
    it "active な StopCondition がなければ false" do
      expect(described_class.blocked?("DailyRunner")).to be false
    end

    it "対象 Runner を止める active StopCondition があれば true" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "テスト用ブロック", severity: "high", created_by: "admin"
      )
      expect(described_class.blocked?("DailyRunner")).to be true
    end

    it "target_type: all の StopCondition はすべての Runner をブロック" do
      LedgerV2::StopCondition.create!(
        target_type: "all",
        reason: "全停止", severity: "critical", created_by: "admin"
      )
      expect(described_class.blocked?("WeeklyRunner")).to be true
    end

    it "異なる Runner の StopCondition は影響しない" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "Daily のみ停止", severity: "low", created_by: "admin"
      )
      expect(described_class.blocked?("WeeklyRunner")).to be false
    end

    it "active: false の StopCondition は blocked にしない" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "解除済み", severity: "low", created_by: "admin", active: false
      )
      expect(described_class.blocked?("DailyRunner")).to be false
    end
  end

  describe ".reason_for" do
    it "ブロックされていなければ nil" do
      expect(described_class.reason_for("DailyRunner")).to be_nil
    end

    it "ブロックされているときはその理由を返す" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "障害調査中のため一時停止", severity: "high", created_by: "admin"
      )
      expect(described_class.reason_for("DailyRunner")).to eq("障害調査中のため一時停止")
    end

    it "複数 StopCondition がある場合は severity が高い方の理由を返す" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "低優先度の理由", severity: "low", created_by: "admin"
      )
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "DailyRunner",
        reason: "緊急停止", severity: "critical", created_by: "admin"
      )
      expect(described_class.reason_for("DailyRunner")).to eq("緊急停止")
    end
  end
end
