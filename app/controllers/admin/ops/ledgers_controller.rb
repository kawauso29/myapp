class Admin::Ops::LedgersController < Admin::Ops::BaseController
  LEDGER_CADENCE_CONFIG = [
    { cadence: :daily,     meeting_key: "daily",            job_class: "DailyLedgerRunJob",           interval: 30.minutes },
    { cadence: :weekly,    meeting_key: "weekly_dept",      job_class: "WeeklyDeptLedgerRunJob",      interval: 4.hours    },
    { cadence: :monthly,   meeting_key: "monthly_ops",      job_class: "MonthlyOpsLedgerRunJob",      interval: 12.hours   },
    { cadence: :quarterly, meeting_key: "quarterly_review", job_class: "QuarterlyReviewLedgerRunJob", interval: 2.days     },
    { cadence: :annual,    meeting_key: "annual_plan",      job_class: "AnnualPlanLedgerRunJob",      interval: 7.days     }
  ].freeze

  LEDGER_SERVICES = %w[ai_sns trading picro].freeze

  # ダッシュボード or cadence/service 別実行一覧
  def index
    @service_id  = params[:service_id].presence
    @meeting_key = params[:meeting_key].presence

    @cadence_health  = build_cadence_health
    @alert_summary   = build_alert_summary
    @service_overview = build_service_overview unless @meeting_key.present?

    if @meeting_key.present?
      # cadence 詳細モード: 当該 meeting_key の実行履歴一覧
      @cadence_cfg = LEDGER_CADENCE_CONFIG.find { |c| c[:meeting_key] == @meeting_key }
      scope = MeetingLedger.where(meeting_key: @meeting_key)
      scope = scope.where(service_id: @service_id) if @service_id.present?
      @meeting_ledgers = scope.order(held_at: :desc).limit(50)

      ticket_scope = TicketLedger.joins(:source_meeting)
                                 .where(meeting_ledgers: { meeting_key: @meeting_key })
      ticket_scope = ticket_scope.where(ticket_ledgers: { service_id: @service_id }) if @service_id.present?
      @ticket_ledgers = ticket_scope.includes(:source_meeting).order(created_at: :desc).limit(100)
    else
      # ダッシュボードモード: 最新 20 件（全cadence）
      scope = MeetingLedger.order(held_at: :desc)
      scope = scope.where(service_id: @service_id) if @service_id.present?
      @recent_runs = scope.limit(20)
    end

    @open_improvement_count = TicketLedger.ticket_type_improvement.status_waiting_review.count
  end

  # 単一 MeetingLedger の詳細
  def show
    @meeting = MeetingLedger.find(params[:id])
    @cadence_cfg = LEDGER_CADENCE_CONFIG.find { |c| c[:meeting_key] == @meeting.meeting_key }
    @related_tickets = TicketLedger.where(source_meeting: @meeting).order(:id)
    @job_row = fetch_job_row_for_meeting(@meeting)
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

  def build_cadence_health
    service_filter = @service_id.presence

    LEDGER_CADENCE_CONFIG.map do |cfg|
      scope = MeetingLedger.where(meeting_key: cfg[:meeting_key])
      scope = scope.where(service_id: service_filter) if service_filter

      last_meeting = scope.order(held_at: :desc).first
      last_held_at = last_meeting&.held_at
      age          = last_held_at ? (Time.current - last_held_at) : nil
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

      total_count = scope.count
      job_rows, fail_count = fetch_recent_ledger_jobs(cfg[:job_class])

      {
        cadence:      cfg[:cadence],
        meeting_key:  cfg[:meeting_key],
        job_class:    cfg[:job_class],
        interval:     cfg[:interval],
        last_held_at: last_held_at,
        last_id:      last_meeting&.id,
        age_seconds:  age,
        status:       status,
        total_count:  total_count,
        job_rows:     job_rows,
        fail_count:   fail_count
      }
    end
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_cadence_health: #{e.message}")
    []
  end

  def build_service_overview
    services = LEDGER_SERVICES
    {
      meeting: MeetingLedger.where(service_id: services).group(:service_id).count,
      ticket:  TicketLedger.where(service_id: services).group(:service_id).count,
      stop:    StopLedger.status_active.where(service_id: services).group(:service_id).count
    }
  rescue StandardError => e
    Rails.logger.warn("Admin::Ops::LedgersController#build_service_overview: #{e.message}")
    {}
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

  def fetch_job_row_for_meeting(meeting)
    cfg = LEDGER_CADENCE_CONFIG.find { |c| c[:meeting_key] == meeting.meeting_key }
    return nil unless cfg

    # held_at の前後 2 interval 以内に finished した SolidQueue::Job を探す
    window_start = meeting.held_at - cfg[:interval]
    window_end   = meeting.held_at + cfg[:interval]
    job = SolidQueue::Job
            .where(class_name: cfg[:job_class])
            .where(finished_at: window_start..window_end)
            .order(finished_at: :desc)
            .first
    return nil unless job

    failed = SolidQueue::FailedExecution.exists?(job_id: job.id)
    { job:, failed: }
  rescue StandardError
    nil
  end
end
