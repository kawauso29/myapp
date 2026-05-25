require "rails_helper"

RSpec.describe Linestamp::ComposeBrandPromptJob, type: :job do
  let(:brand) do
    Linestamp::Brand.create!(
      slug: "test",
      character_name: "Test Brand",
      series_name: "Test Series",
      description: "A test",
      two_part_definition: "Test definition",
      character_parts: { eyes: "half-closed" },
      font_spec: { primary: "Gothic" },
      tone_axes: { gentle: 0.5 },
      background_color_for_gen: "#3CB371"
    )
  end

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
