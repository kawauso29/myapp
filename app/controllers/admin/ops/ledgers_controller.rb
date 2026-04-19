class Admin::Ops::LedgersController < Admin::Ops::BaseController
  LEDGER_CADENCE_CONFIG = [
    { cadence: :daily,     meeting_key: "daily",           job_class: "DailyLedgerRunJob",          interval: 30.minutes },
    { cadence: :weekly,    meeting_key: "weekly_dept",     job_class: "WeeklyDeptLedgerRunJob",     interval: 4.hours    },
    { cadence: :monthly,   meeting_key: "monthly_ops",     job_class: "MonthlyOpsLedgerRunJob",     interval: 12.hours   },
    { cadence: :quarterly, meeting_key: "quarterly_review", job_class: "QuarterlyReviewLedgerRunJob", interval: 2.days  },
    { cadence: :annual,    meeting_key: "annual_plan",     job_class: "AnnualPlanLedgerRunJob",     interval: 7.days     }
  ].freeze

  def index
    @service_id = params[:service_id].presence
    @meeting_key = params[:meeting_key].presence

    meeting_scope = MeetingLedger.order(held_at: :desc, id: :desc)
    meeting_scope = meeting_scope.where(service_id: @service_id) if @service_id.present?
    meeting_scope = meeting_scope.where(meeting_key: @meeting_key) if @meeting_key.present?
    @meeting_ledgers = meeting_scope.limit(50)

    ticket_scope = TicketLedger.order(created_at: :desc, id: :desc)
    ticket_scope = ticket_scope.where(service_id: @service_id) if @service_id.present?
    if @meeting_key.present?
      ticket_scope = ticket_scope.joins(:source_meeting).where(meeting_ledgers: { meeting_key: @meeting_key })
    end
    @ticket_ledgers = ticket_scope.includes(:source_meeting).limit(100)
    @open_improvement_count = TicketLedger.ticket_type_improvement.status_waiting_review.count

    @alert_summary = build_alert_summary
    @service_summaries = build_service_summaries unless @service_id.present?
    @cadence_health = build_cadence_health
  end

  private

  def build_alert_summary
    {
      waiting_review: TicketLedger.ticket_type_improvement.status_waiting_review.count,
      overdue:        TicketLedger.status_overdue.count,
      non_approval:   AuditDecisionLedger.non_approvals.count,
      active_stop:    StopLedger.status_active.count
    }
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_alert_summary: #{e.message}")
    {}
  end

  def build_service_summaries
    services = %w[ai_sns trading picro]
    {
      meeting: MeetingLedger.where(service_id: services).group(:service_id).count,
      ticket:  TicketLedger.where(service_id: services).group(:service_id).count,
      stop:    StopLedger.status_active.where(service_id: services).group(:service_id).count
    }
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_service_summaries: #{e.message}")
    {}
  end

  def build_cadence_health
    service_filter = @service_id.presence

    LEDGER_CADENCE_CONFIG.map do |cfg|
      scope = MeetingLedger.where(meeting_key: cfg[:meeting_key])
      scope = scope.where(service_id: service_filter) if service_filter

      last_meeting = scope.order(held_at: :desc).first
      last_held_at = last_meeting&.held_at
      age = last_held_at ? (Time.current - last_held_at) : nil
      interval_sec = cfg[:interval].to_i

      status =
        if last_held_at.nil?
          :missing
        elsif age <= interval_sec * 2
          :healthy
        elsif age <= interval_sec * 5
          :late
        else
          :stale
        end

      recent_count = scope.where("held_at > ?", (cfg[:interval] * 10).ago).count

      job_rows, fail_count = fetch_recent_ledger_jobs(cfg[:job_class])

      {
        cadence: cfg[:cadence],
        meeting_key: cfg[:meeting_key],
        job_class: cfg[:job_class],
        interval: cfg[:interval],
        last_held_at: last_held_at,
        age_seconds: age,
        status: status,
        recent_count: recent_count,
        job_rows: job_rows,
        fail_count: fail_count,
        last_job_ok: job_rows.first ? !job_rows.first[:failed] : nil
      }
    end
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_cadence_health: #{e.message}")
    []
  end

  def fetch_recent_ledger_jobs(job_class)
    recent_jobs = SolidQueue::Job
                    .where(class_name: job_class)
                    .where.not(finished_at: nil)
                    .order(finished_at: :desc)
                    .limit(10)
    failed_ids = SolidQueue::FailedExecution.where(job_id: recent_jobs.select(:id)).pluck(:job_id).to_set
    rows = recent_jobs.map { |j| { at: j.finished_at, failed: failed_ids.include?(j.id) } }
    [ rows, failed_ids.size ]
  rescue StandardError
    [ [], 0 ]
  end
end
