require "rails_helper"
require "rake"
require "stringio"

RSpec.describe "ops rake tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  describe "ops:smoke_test" do
    let(:task) { Rake::Task["ops:smoke_test"] }

    before do
      task.reenable
      migration_context = double("MigrationContext", pending_migration_versions: [])
      allow(ActiveRecord::Base.connection_pool).to receive(:migration_context).and_return(migration_context)
      allow(Ledgers::WeeklyDeptRunner).to receive(:call)
      allow(Ledgers::MonthlyOpsRunner).to receive(:call)
      allow(TicketOverdueCheckJob).to receive(:perform_now).and_return(0)
    end

    it "runs all checks and prints success summary" do
      output = capture_stdout { task.invoke }

      expect(output).to include("[OK] db:migrate:status")
      expect(output).to include("[OK] weekly_dept_runner")
      expect(output).to include("[OK] monthly_ops_runner")
      expect(output).to include("[OK] ticket_overdue_check")
      expect(output).to include("All checks passed")
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
