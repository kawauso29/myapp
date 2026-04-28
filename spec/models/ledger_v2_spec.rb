require "rails_helper"

RSpec.describe LedgerV2 do
  it "is defined as a module" do
    expect(LedgerV2).to be_a(Module)
  end

  it "autoloads from app/models/ledger_v2/ directory" do
    expect(defined?(LedgerV2)).to eq("constant")
  end
end
