require "rails_helper"

RSpec.describe Admin::AiSnsPlanService do
  describe ".stats / .next_item / .items_by_priority" do
    before do
      # Create via DevInitiative to exercise the after_save mirror that builds TicketLedger.
      DevInitiative.create!(item_key: "X1", title: "X1 todo high", priority: :high,   status: :todo)
      DevInitiative.create!(item_key: "X2", title: "X2 todo med",  priority: :medium, status: :todo, notes: "X2 note")
      DevInitiative.create!(item_key: "X3", title: "X3 wip low",   priority: :low,    status: :in_progress)
      DevInitiative.create!(item_key: "X4", title: "X4 done high", priority: :high,   status: :done, completed_at: 2.days.ago)
    end

    it "reads counts from TicketLedger.ai_sns_plan" do
      stats = described_class.stats
      expect(stats[:total]).to eq(4)
      expect(stats[:todo]).to eq(2)
      expect(stats[:in_progress]).to eq(1)
      expect(stats[:done]).to eq(1)
    end

    it "selects next_item from TicketLedger draft tickets ordered by priority" do
      item = described_class.next_item
      expect(item).to be_present
      expect(item["id"]).to eq("X1")
      expect(item["title"]).to eq("X1 todo high")
      expect(item["priority"]).to eq("high")
    end

    it "groups items_by_priority by ledger priority and maps status back to legacy labels" do
      grouped = described_class.items_by_priority
      expect(grouped["high"].keys).to contain_exactly("X1", "X4")
      expect(grouped["high"]["X4"]["status"]).to eq("done")
      expect(grouped["medium"]["X2"]["notes"]).to eq("X2 note")
      expect(grouped["low"]["X3"]["status"]).to eq("in_progress")
    end
  end
end
