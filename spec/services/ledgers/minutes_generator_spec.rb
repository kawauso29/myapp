require "rails_helper"

RSpec.describe Ledgers::MinutesGenerator, type: :service do
  describe ".generate" do
    it "必須キーを含むハッシュを返す" do
      result = described_class.generate(
        purpose: "テスト会議",
        agenda: [ "議題1", "議題2" ],
        discussion_log: [ { speaker: "ceo", topic: "KPI", content: "問題なし" } ],
        outcome: "全員承認"
      )
      expect(result).to include(
        "purpose"       => "テスト会議",
        "agenda"        => [ "議題1", "議題2" ],
        "outcome"       => "全員承認"
      )
      expect(result["discussion_log"]).to be_an(Array)
      expect(result["generated_at"]).to be_present
    end

    it "discussion_log のキーが文字列化される" do
      result = described_class.generate(
        purpose: "テスト",
        agenda: [],
        discussion_log: [ { speaker: "ceo", topic: "T", content: "C" } ],
        outcome: "完了"
      )
      entry = result["discussion_log"].first
      expect(entry.keys).to all(be_a(String))
    end
  end

  describe ".for_daily" do
    let(:kpi_snapshot) { [ { kpi_key: "kpi:dau", grade: "healthy" } ] }
    let(:anomalies)    { [] }
    let(:carry_over)   { [] }

    subject do
      described_class.for_daily(
        service_id:   "ai_sns",
        kpi_snapshot: kpi_snapshot,
        anomalies:    anomalies,
        carry_over:   carry_over
      )
    end

    it "purpose に service_id が含まれる" do
      expect(subject["purpose"]).to include("ai_sns")
    end

    it "異常なしのとき outcome に「正常確認」が含まれる" do
      expect(subject["outcome"]).to include("正常")
    end

    context "異常がある場合" do
      let(:anomalies) { [ { kpi_key: "kpi:dau", grade: "critical", current_value: 0 } ] }

      it "outcome に hold 言及が含まれる" do
        expect(subject["outcome"]).to include("hold_items")
      end

      it "discussion_log に異常検知エントリがある" do
        speakers = subject["discussion_log"].map { |e| e["speaker"] }
        expect(speakers).to include("system")
      end
    end
  end

  describe ".for_weekly" do
    let(:decisions) do
      [
        { title: "KPI対応チケット", result: "approved", ticket_id: 1 },
        { title: "保留チケット",    result: "held_for_missing_kpis" }
      ]
    end
    let(:hold_items)   { [ { title: "保留チケット", reason: "missing_linked_kpis" } ] }
    let(:improvements) { { detected: 2, resolved: 1, details: [] } }
    let(:escalations)  { [] }

    subject do
      described_class.for_weekly(
        service_id:   "ai_sns",
        decisions:    decisions,
        hold_items:   hold_items,
        improvements: improvements,
        escalations:  escalations
      )
    end

    it "purpose に service_id が含まれる" do
      expect(subject["purpose"]).to include("ai_sns")
    end

    it "agenda が配列である" do
      expect(subject["agenda"]).to be_an(Array)
    end

    it "outcome に承認・保留情報が含まれる" do
      expect(subject["outcome"]).to match(/承認|保留/)
    end

    it "discussion_log に各チケットのエントリがある" do
      expect(subject["discussion_log"].size).to be >= 1
    end
  end

  describe ".for_monthly" do
    subject do
      described_class.for_monthly(
        decisions:     [ { ticket_id: 1, resolution: "approved" } ],
        resolved:      2,
        overdue_marked: 0,
        escalated:     1
      )
    end

    it "purpose に「月次」が含まれる" do
      expect(subject["purpose"]).to include("月次")
    end

    it "discussion_log にエントリがある" do
      expect(subject["discussion_log"]).not_to be_empty
    end
  end

  describe ".for_quarterly" do
    let(:metrics) do
      { meetings_held: 10, tickets_total: 50, tickets_approved: 40, tickets_overdue: 3 }
    end

    subject { described_class.for_quarterly(metrics: metrics, quarter: 1, year: 2026) }

    it "purpose に四半期が含まれる" do
      expect(subject["purpose"]).to include("四半期")
    end

    it "outcome に Q1 が含まれる" do
      expect(subject["outcome"]).to include("Q1")
    end
  end

  describe ".for_annual" do
    let(:metrics) do
      { total_meetings: 50, tickets_total: 200, tickets_approved: 180, overdue_rate: "10.0%", quarterly_reviews: 4 }
    end

    subject { described_class.for_annual(metrics: metrics, year: 2026) }

    it "purpose に年次が含まれる" do
      expect(subject["purpose"]).to include("年次")
    end

    it "outcome に FY2026 が含まれる" do
      expect(subject["outcome"]).to include("FY2026")
    end
  end
end
