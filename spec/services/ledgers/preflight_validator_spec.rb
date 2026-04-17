require "rails_helper"

RSpec.describe Ledgers::PreflightValidator do
  let(:definition) do
    build_stubbed(:meeting_definition, participant_roles: %w[planning dev audit cs])
  end

  describe ".call" do
    it "treats nil present_roles as full attendance and returns 1.0 fill_rate" do
      result = described_class.call(definition:, present_roles: nil)

      expect(result.ok?).to be true
      expect(result.missing_roles).to eq([])
      expect(result.role_fill_rate).to eq(1.0)
      expect(result.participants).to match_array(%w[planning dev audit cs])
    end

    it "computes fill rate and missing roles when some roles are absent" do
      result = described_class.call(definition:, present_roles: %w[planning dev audit])

      expect(result.ok?).to be false
      expect(result.missing_roles).to eq([ "cs" ])
      expect(result.role_fill_rate).to eq(0.75)
    end

    it "raises PreflightFailure when fill rate is below required_minimum" do
      expect do
        described_class.call(
          definition:,
          present_roles: %w[planning],
          required_minimum: 0.5
        )
      end.to raise_error(Ledgers::PreflightValidator::PreflightFailure) do |error|
        expect(error.missing_roles).to match_array(%w[dev audit cs])
        expect(error.role_fill_rate).to eq(0.25)
      end
    end

    it "does not raise when participant_roles is empty (fill_rate = 1.0)" do
      empty_definition = build_stubbed(:meeting_definition, participant_roles: [])

      result = described_class.call(definition: empty_definition, present_roles: [])

      expect(result.ok?).to be true
      expect(result.role_fill_rate).to eq(1.0)
    end

    it "ignores present roles that are not listed in the definition" do
      result = described_class.call(definition:, present_roles: %w[planning dev audit cs unknown])

      expect(result.missing_roles).to eq([])
      expect(result.role_fill_rate).to eq(1.0)
    end
  end
end
