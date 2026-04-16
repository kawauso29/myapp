namespace :ops do
  desc "Run smoke test for ops ledger flows"
  task smoke_test: :environment do
    failures = []

    checks = [
      [
        "db:migrate:status",
        lambda {
          pending_versions = ActiveRecord::Base.connection_pool.migration_context.pending_migration_versions
          next if pending_versions.empty?

          versions = pending_versions.join(", ")
          raise "down migrations found: #{versions}"
        }
      ],
      [
        "weekly_dept_runner",
        lambda {
          ApplicationRecord.transaction do
            Ledgers::WeeklyDeptRunner.call(service_id: "ai_sns", ticket_inputs: [])
            raise ActiveRecord::Rollback
          end
        }
      ],
      [
        "monthly_ops_runner",
        lambda {
          ApplicationRecord.transaction do
            Ledgers::MonthlyOpsRunner.call
            raise ActiveRecord::Rollback
          end
        }
      ],
      [
        "ticket_overdue_check",
        lambda {
          ApplicationRecord.transaction do
            TicketOverdueCheckJob.perform_now
            raise ActiveRecord::Rollback
          end
        }
      ]
    ]

    checks.each do |check_name, callable|
      callable.call
      puts "[OK] #{check_name}"
    rescue StandardError => e
      failures << "#{check_name}: #{e.class} - #{e.message}"
      puts "[NG] #{check_name}: #{e.class} - #{e.message}"
    end

    if failures.empty?
      puts "All checks passed"
    else
      puts "Smoke test failed:"
      failures.each { |failure| puts "- #{failure}" }
    end
  end
end
