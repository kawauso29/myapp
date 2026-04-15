require "rails_helper"
require "rake"

RSpec.describe "ledgers rake tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  describe "ledgers:run_weekly_dept" do
    let(:task) { Rake::Task["ledgers:run_weekly_dept"] }

    before do
      task.reenable
      allow(Ledgers::WeeklyDeptRunner).to receive(:call).and_return(instance_double(MeetingLedger, id: 1, tickets_to_create: [], hold_items: []))
    end

    it "runs without raising" do
      expect { task.invoke("ai_sns") }.not_to raise_error
      expect(Ledgers::WeeklyDeptRunner).to have_received(:call).with(service_id: "ai_sns")
    end
  end

  describe "ledgers:run_monthly_ops" do
    let(:task) { Rake::Task["ledgers:run_monthly_ops"] }

    before do
      task.reenable
      allow(Ledgers::MonthlyOpsRunner).to receive(:call).and_return(instance_double(MeetingLedger, id: 1, decisions: []))
    end

    it "runs without raising" do
      expect { task.invoke }.not_to raise_error
      expect(Ledgers::MonthlyOpsRunner).to have_received(:call)
    end
  end
end
