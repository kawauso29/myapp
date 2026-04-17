require "rails_helper"

RSpec.describe StopConditionMonitorJob, type: :job do
  describe "#perform" do
    context "with explicit scope" do
      it "evaluates and lifts for the given single scope" do
        evaluator = instance_double(Stops::ConditionEvaluator, call: nil, lift_resolved!: nil)
        expect(Stops::ConditionEvaluator).to receive(:new)
          .with(scope_level: :service, service_id: "ai_sns")
          .and_return(evaluator)
        expect(evaluator).to receive(:call)
        expect(evaluator).to receive(:lift_resolved!)

        described_class.new.perform(scope_level: :service, service_id: "ai_sns")
      end
    end

    context "without arguments (multi-scope mode)" do
      it "evaluates company scope and every active service" do
        create(:service_ledger, service_id: "ai_sns")
        create(:service_ledger, service_id: "another_service")

        seen_args = []
        allow(Stops::ConditionEvaluator).to receive(:new) do |scope_level:, service_id:|
          seen_args << [ scope_level, service_id ]
          instance_double(Stops::ConditionEvaluator, call: nil, lift_resolved!: nil)
        end

        described_class.new.perform

        expect(seen_args).to include([ :company, nil ])
        expect(seen_args).to include([ :service, "ai_sns" ])
        expect(seen_args).to include([ :service, "another_service" ])
      end
    end
  end
end
