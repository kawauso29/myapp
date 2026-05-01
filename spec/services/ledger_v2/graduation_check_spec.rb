require "rails_helper"

RSpec.describe LedgerV2::GraduationCheck, type: :service do
  # 「7 基準を一覧で返す」「全部 ok なら all_pass? が true」の最小契約を確認する。
  # snapshot の作り方を最低限示すヘルパだけを用意し、テストは 2 シナリオ（all-pass / 1つ NG）に絞る。

  def create_passing_snapshot
    LedgerV2::HealthSnapshot.create!(
      period:                            :daily,
      measured_at:                       Time.current,
      ticket_noise_rate:                 0.10,   # <= 0.30 OK
      artifact_acceptance_rate:          0.80,   # >= 0.50 OK
      runner_failure_rate:               0.05,   # <= 0.10 OK
      unresolved_ticket_age_avg:         12.0,
      human_intervention_rate:           0.10,
      kpi_improvement_after_ticket_rate: 0.50,
      stop_trigger_count:                0,
      duplicate_prevented_count:         3,
      pending_review_count:              5,      # <= 20 OK
      open_ticket_count:                 4
    )
  end

  describe ".call" do
    it "7 基準すべての結果を返す" do
      results = described_class.call
      expect(results.size).to eq(7)
      expect(results.map(&:key)).to match_array(described_class::CRITERIA.map { |c| c[:key] })
    end

    it "snapshot が無くても安全にフォールバック値で評価する" do
      results = described_class.call
      # 値はすべて非 nil で、ok? は true/false いずれかになる
      expect(results.map(&:value)).to all(satisfy { |v| !v.nil? })
    end
  end

  describe ".all_pass?" do
    it "卒業基準を全て満たしていれば true を返す" do
      create_passing_snapshot
      # 重複防止の実績を 1 以上にする
      LedgerV2::Run.create!(
        runner_name:               "DailyRunner",
        trigger_type:              :schedule,
        started_at:                1.hour.ago,
        duplicate_prevented_count: 2
      )
      # snapshot 件数を 7 件以上にする（criterion #6: HealthSnapshot.count >= 7）
      # 日付は無関係だが unique(period, measured_at) 制約があるので別 measured_at で作る
      6.times do |i|
        LedgerV2::HealthSnapshot.create!(
          period:                            :daily,
          measured_at:                       (i + 1).days.ago,
          ticket_noise_rate:                 0.0,
          artifact_acceptance_rate:          0.0,
          runner_failure_rate:               0.0,
          unresolved_ticket_age_avg:         0.0,
          human_intervention_rate:           0.0,
          kpi_improvement_after_ticket_rate: 0.0,
          stop_trigger_count:                0,
          duplicate_prevented_count:         0,
          pending_review_count:              0,
          open_ticket_count:                 0
        )
      end

      expect(described_class.all_pass?).to be(true)
    end

    it "1 つでも基準を満たさなければ false を返す" do
      create_passing_snapshot
      # active StopCondition を 1 件作って NG にする
      LedgerV2::StopCondition.create!(
        target_type: "runner",
        target_name: "DailyRunner",
        reason:      "test stop",
        severity:    "high",
        created_by:  "admin",
        active:      true
      )

      results = described_class.call
      stop_result = results.find { |r| r.key == :stop_trigger_count_active }
      expect(stop_result.ok?).to be(false)
      expect(described_class.all_pass?).to be(false)
    end
  end
end
