class HrEvaluationRunJob < ApplicationJob
  include Ledgers::JobIdempotency
  queue_as :default

  # Phase 38b / §19: 四半期ごとに主要ロールの人事評価を自動実行する。
  #
  # 対象ロールは TicketLedger.owner_dept / assignee に出現した上位ロールを動的に抽出し、
  # 直前の `EVALUATION_PERIOD_DAYS` 日を評価期間として `Hr::Evaluator` に渡す。
  SUBJECT_ROLE_LIMIT = 20
  EVALUATION_PERIOD_DAYS = 90

  def perform
    quarter_number = ((Date.current.month - 1) / 3) + 1
    key = "hr_evaluation:#{Date.current.year}:q#{quarter_number}"

    self.class.with_job_idempotency(key) do
      period_end = Date.current - 1
      period_start = period_end - EVALUATION_PERIOD_DAYS

      roles = collect_subject_roles(period_start, period_end)
      roles.each do |role, service_id|
        Hr::Evaluator.call(
          subject_role: role,
          service_id: service_id,
          scope_level: service_id.present? ? :service : :company,
          period_start: period_start,
          period_end: period_end
        )
      rescue StandardError => e
        Rails.logger.error("[HrEvaluationRunJob] role=#{role} service=#{service_id} failed: #{e.class}: #{e.message}")
      end
    end
  end

  private

  def collect_subject_roles(period_start, period_end)
    # 出現頻度の高い (owner_dept, service_id) 組を上位から抽出する。
    base = TicketLedger.where(created_at: period_start.beginning_of_day..period_end.end_of_day)
                       .where.not(owner_dept: nil)
    base.group(:owner_dept, :service_id)
        .order(Arel.sql("count(*) DESC"))
        .limit(SUBJECT_ROLE_LIMIT)
        .count
        .keys
  end
end
