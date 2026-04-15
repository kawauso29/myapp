namespace :ledgers do
  desc "Run weekly_dept ledger flow for a service"
  task :run_weekly_dept, [ :service_id ] => :environment do |_task, args|
    service_id = args[:service_id].presence || "ai_sns"
    meeting = Ledgers::WeeklyDeptRunner.call(service_id:)

    puts "weekly_dept done: meeting_ledger_id=#{meeting.id} tickets=#{meeting.tickets_to_create.size} holds=#{meeting.hold_items.size}"
  end

  desc "Run monthly_ops ledger flow"
  task run_monthly_ops: :environment do
    meeting = Ledgers::MonthlyOpsRunner.call
    puts "monthly_ops done: meeting_ledger_id=#{meeting.id} resolved=#{meeting.decisions.size}"
  end
end
