namespace :ledgers do
  desc "Run weekly_dept ledger flow for a service"
  task :run_weekly_dept, [ :service_id ] => :environment do |_task, args|
    service_id = args[:service_id].presence || "ai_sns"
    meeting = Ledgers::WeeklyDeptRunner.call(service_id:)

    puts Ledgers::RunOutputFormatter.format(meeting:, operation: "weekly_dept")
  end

  desc "Run monthly_ops ledger flow"
  task run_monthly_ops: :environment do
    meeting = Ledgers::MonthlyOpsRunner.call
    puts Ledgers::RunOutputFormatter.format(meeting:, operation: "monthly_ops")
  end

  desc "Run quarterly_review ledger flow"
  task run_quarterly_review: :environment do
    meeting = Ledgers::QuarterlyReviewRunner.call
    puts Ledgers::RunOutputFormatter.format(meeting:, operation: "quarterly_review")
  end

  desc "Run annual_plan ledger flow"
  task run_annual_plan: :environment do
    meeting = Ledgers::AnnualPlanRunner.call
    puts Ledgers::RunOutputFormatter.format(meeting:, operation: "annual_plan")
  end

  desc "Check overdue waiting_review tickets and mark as overdue"
  task check_overdue: :environment do
    overdue_count = TicketOverdueCheckJob.perform_now
    puts JSON.pretty_generate(
      {
        operation: "check_overdue",
        overdue_marked: overdue_count
      }
    )
  end

  desc "Detect and resolve improvement tickets"
  task detect_improvements: :environment do
    detected = Ledgers::ImprovementDetector.call
    resolved = Ledgers::ImprovementResolver.call
    improvements = {
      detected: detected[:detected] || detected["detected"] || 0,
      resolved: resolved[:resolved] || resolved["resolved"] || 0,
      details: Array(detected[:details] || detected["details"]) + Array(resolved[:details] || resolved["details"])
    }

    puts JSON.pretty_generate(
      {
        operation: "detect_improvements",
        improvements:
      }
    )
  end
end
