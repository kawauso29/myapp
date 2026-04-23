require "rails_helper"

RSpec.describe DevInitiative, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      initiative = described_class.new(item_key: "X1", title: "Test", priority: :medium, status: :todo)
      expect(initiative).to be_valid
    end

    it "requires item_key" do
      initiative = described_class.new(title: "Test", priority: :medium, status: :todo)
      expect(initiative).not_to be_valid
      expect(initiative.errors[:item_key]).to be_present
    end

    it "requires title" do
      initiative = described_class.new(item_key: "X1", priority: :medium, status: :todo)
      expect(initiative).not_to be_valid
      expect(initiative.errors[:title]).to be_present
    end

    it "enforces uniqueness on item_key" do
      described_class.create!(item_key: "X1", title: "Test", priority: :medium, status: :todo)
      dup = described_class.new(item_key: "X1", title: "Another", priority: :high, status: :todo)
      expect(dup).not_to be_valid
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(described_class.statuses).to eq("todo" => 0, "in_progress" => 1, "done" => 2)
    end

    it "has correct priority values" do
      expect(described_class.priorities).to eq("low" => 0, "medium" => 1, "high" => 2)
    end
  end

  describe "scopes" do
    before do
      described_class.create!(item_key: "T1", title: "Todo High",   priority: :high,   status: :todo)
      described_class.create!(item_key: "T2", title: "Todo Low",    priority: :low,    status: :todo)
      described_class.create!(item_key: "T3", title: "In Progress", priority: :medium, status: :in_progress)
      described_class.create!(item_key: "T4", title: "Done",        priority: :high,   status: :done)
    end

    it "status_todo returns only todo items" do
      expect(described_class.status_todo.pluck(:item_key)).to contain_exactly("T1", "T2")
    end

    it "status_in_progress returns only in_progress items" do
      expect(described_class.status_in_progress.pluck(:item_key)).to contain_exactly("T3")
    end

    it "status_done returns only done items" do
      expect(described_class.status_done.pluck(:item_key)).to contain_exactly("T4")
    end

    it "next_todo returns highest priority todo first" do
      first = described_class.next_todo.first
      expect(first.item_key).to eq("T1")
    end
  end
end
