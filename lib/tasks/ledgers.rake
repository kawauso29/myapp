namespace :ledgers do
  desc "Idempotently seed all required ledger master data (MeetingDefinition / ServiceLedger / KpiLedger / LaneCapacityCap). Safe to run on every deploy."
  task seed_master_data: :environment do
    Ledgers::MasterDataSeeder.call
    result = Ledgers::SeedValidator.call
    if result.ok?
      puts "ledgers:seed_master_data: OK - all required records present"
    else
      $stderr.puts "ledgers:seed_master_data: MISSING records after seed: #{result.errors_text}"
      exit 1
    end
  end

  desc "Idempotently seed per-service plan items from db/seeds/plans/*.yml into TicketLedger via PlanItemUpserter. Safe to run on every deploy."
  task seed_plans: :environment do
    result = Ledgers::ServicePlanSeeder.call
    puts JSON.pretty_generate(
      operation: "seed_plans",
      files: result.files,
      upserted: result.upserted
    )
  end

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
      detected: detected.fetch(:detected, 0),
      resolved: resolved.fetch(:resolved, 0),
      details: Array(detected.fetch(:details, [])) + Array(resolved.fetch(:details, []))
    }

    puts JSON.pretty_generate(
      {
        operation: "detect_improvements",
        improvements:
      }
    )
  end

  desc "Escalate unresolved improvement tickets"
  task escalate_improvements: :environment do
    result = Ledgers::ImprovementEscalator.call
    puts JSON.pretty_generate(result)
  end

  desc "Verify that required seed records (MeetingDefinition / ServiceLedger / KpiLedger) exist in the database"
  task verify_seeds: :environment do
    result = Ledgers::SeedValidator.call

    if result.ok?
      puts JSON.pretty_generate({ status: "ok", message: "All required seed records are present." })
    else
      puts JSON.pretty_generate({ status: "missing", details: result.missing })
      $stderr.puts "ERROR: Required seed records are missing. Run `rails db:seed` to fix."
      exit 1
    end
  end
end
