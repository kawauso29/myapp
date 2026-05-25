require "rails_helper"

RSpec.describe Linestamp::ComposeBrandPromptJob, type: :job do
  let(:brand) { Linestamp::Brand.create!(slug: "test", name: "Test Brand", description: "A test") }

  it "composes brand prompt and transitions state" do
    described_class.perform_now(brand.id)

    brand.reload
    expect(brand.brand_prompt).to be_present
    expect(brand).to be_prompt_ready
  end

  it "skips non-planned brands" do
    brand.update!(brand_prompt: "existing", status: "prompt_ready")
    described_class.perform_now(brand.id)

    brand.reload
    expect(brand.brand_prompt).to eq("existing")
  end
end
