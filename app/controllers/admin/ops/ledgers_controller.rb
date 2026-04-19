class Admin::Ops::LedgersController < Admin::Ops::BaseController
  LEDGER_CADENCE_CONFIG = [
    { cadence: :daily,     meeting_key: "daily",            job_class: "DailyLedgerRunJob",           interval: 30.minutes },
    { cadence: :weekly,    meeting_key: "weekly_dept",      job_class: "WeeklyDeptLedgerRunJob",      interval: 4.hours    },
    { cadence: :monthly,   meeting_key: "monthly_ops",      job_class: "MonthlyOpsLedgerRunJob",      interval: 12.hours   },
    { cadence: :quarterly, meeting_key: "quarterly_review", job_class: "QuarterlyReviewLedgerRunJob", interval: 2.days     },
    { cadence: :annual,    meeting_key: "annual_plan",      job_class: "AnnualPlanLedgerRunJob",      interval: 7.days     }
  ].freeze

  LEDGER_SERVICES = %w[ai_sns trading picro].freeze

  # ① 会社全体サマリ（トップページ）
  def index
    @cadence_health  = build_cadence_health
    @alert_summary   = build_alert_summary_extended

    @company_kpis    = KpiLedger.scope_level_company.order(:kpi_key)
    @all_kpis        = KpiLedger.order(:scope_level, :kpi_key)

    @last_major_meetings = {
      annual:    MeetingLedger.where(meeting_key: "annual_plan").order(held_at: :desc).first,
      quarterly: MeetingLedger.where(meeting_key: "quarterly_review").order(held_at: :desc).first,
      monthly:   MeetingLedger.where(meeting_key: "monthly_ops").order(held_at: :desc).first
    }

    @annual_directives   = Array(@last_major_meetings[:annual]&.directives).reject(&:blank?)
    @quarterly_directives = Array(@last_major_meetings[:quarterly]&.directives).reject(&:blank?)

    @next_heartbeats = ServiceHeartbeat
                         .status_active
                         .where.not(next_run_at: nil)
                         .where("next_run_at > ?", Time.current)
                         .order(:next_run_at)
                         .includes(:meeting_definition)
                         .limit(10)

    @service_overview = build_service_overview
  rescue StandardError => e
    Rails.logger.warn("LedgersController#index: #{e.message}")
  end

  # 既存: 単一 MeetingLedger 詳細
  def show
    @meeting = MeetingLedger.find(params[:id])
    @cadence_cfg = LEDGER_CADENCE_CONFIG.find { |c| c[:meeting_key] == @meeting.meeting_key }
    @related_tickets = TicketLedger.where(source_meeting: @meeting).order(:id)
    @job_row = fetch_job_row_for_meeting(@meeting)
  end

  # ② サービス別サマリ
  def services
    @services_data = LEDGER_SERVICES.map { |svc| build_service_data(svc) }
  end

  def service_detail
    @service_id = params[:service_id]
    unless LEDGER_SERVICES.include?(@service_id)
      redirect_to admin_ops_ledger_services_path, alert: "不明なサービス: #{@service_id}"
      return
    end

    @service_ledger  = ServiceLedger.find_by(service_id: @service_id)
    @kpis            = KpiLedger.where(service_id: @service_id).order(:kpi_key)
    @recent_meetings = MeetingLedger.where(service_id: @service_id).order(held_at: :desc).limit(10)
    @open_tickets    = TicketLedger
                         .where(service_id: @service_id)
                         .where.not(status: %i[completed cancelled].map { |s| TicketLedger.statuses[s] })
                         .order(due_date: :asc)
                         .limit(50)
    @experiments     = ExperimentLedger.where(service_id: @service_id).order(deadline: :asc).limit(20)
    @cadence_health  = build_cadence_health(service_filter: @service_id)
    @alert_summary   = build_alert_summary(service_id: @service_id)
  rescue StandardError => e
    Rails.logger.warn("LedgersController#service_detail: #{e.message}")
  end

  # ③ スケジュール・チケット情報
  def schedule
    @upcoming_heartbeats = ServiceHeartbeat
                             .status_active
                             .where.not(next_run_at: nil)
                             .where("next_run_at > ?", Time.current)
                             .order(:next_run_at)
                             .includes(:meeting_definition)
                             .limit(50)

    @past_heartbeats = ServiceHeartbeat
                         .status_active
                         .where.not(last_run_at: nil)
                         .where("last_run_at > ?", 24.hours.ago)
                         .order(last_run_at: :desc)
                         .includes(:meeting_definition)
                         .limit(30)

    @recent_meetings = MeetingLedger
                         .where("held_at > ?", 24.hours.ago)
                         .order(held_at: :desc)

    @open_tickets = TicketLedger
                      .where.not(status: %i[completed cancelled].map { |s| TicketLedger.statuses[s] })
                      .order(Arel.sql("due_date IS NULL ASC, due_date ASC"))
                      .limit(100)
  rescue StandardError => e
    Rails.logger.warn("LedgersController#schedule: #{e.message}")
  end

  # ④ 各部毎の情報
  def departments
    @roles_by_category = OrganizationRole.active.order(:category, :role_key).group_by(&:category)
    @meeting_def_counts = MeetingDefinition.group(:chair_role).count
    @hr_eval_counts     = HrEvaluationLedger.group(:subject_role).count
    @org_change_counts  = OrgChangeLedger.group(:scope_level).count
  rescue StandardError => e
    Rails.logger.warn("LedgersController#departments: #{e.message}")
  end

  def department_detail
    @role = OrganizationRole.find_by!(role_key: params[:role_key])

    @chaired_defs   = MeetingDefinition.where(chair_role: @role.role_key)
    @participant_defs = MeetingDefinition
                          .where("participant_roles @> ?", "[\"#{@role.role_key}\"]")
    @all_defs = (@chaired_defs + @participant_defs).uniq

    @recent_meetings = MeetingLedger
                         .where(chair: @role.role_key)
                         .order(held_at: :desc)
                         .limit(20)

    @hr_evals  = HrEvaluationLedger
                   .where(subject_role: @role.role_key)
                   .order(period_end: :desc)
                   .limit(10)
    @org_changes = OrgChangeLedger
                     .order(created_at: :desc)
                     .limit(10)
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ops_ledger_departments_path, alert: "役割が見つかりません"
  rescue StandardError => e
    Rails.logger.warn("LedgersController#department_detail: #{e.message}")
  end

  # ⑤ 承認ログ
  def approvals
    @decision_filter  = params[:decision].presence
    @service_filter   = params[:service_id].presence

    scope = AuditDecisionLedger.order(decided_at: :desc, id: :desc)
    if @decision_filter.present? && AuditDecisionLedger.decisions.key?(@decision_filter)
      scope = scope.where(decision: AuditDecisionLedger.decisions[@decision_filter])
    end
    scope = scope.where(service_id: @service_filter) if @service_filter.present?
    @audit_decisions = scope.limit(100)

    @operator_overrides = OperatorOverrideLedger.order(started_at: :desc).limit(30)
    @recent_stops       = StopLedger.order(started_at: :desc).limit(20)
    @active_halts       = OperatorOverrideLedger.currently_active
    @decision_counts    = AuditDecisionLedger.group(:decision).count.transform_keys { |k|
      AuditDecisionLedger.decisions.key(k) || k.to_s
    }
  rescue StandardError => e
    Rails.logger.warn("LedgersController#approvals: #{e.message}")
  end

  # ⑥ エラーログ
  def errors
    failed_jobs = SolidQueue::FailedExecution
                    .joins(:job)
                    .order("solid_queue_failed_executions.created_at DESC")
                    .limit(50)
    @failed_jobs = failed_jobs.map { |fe|
      { id: fe.id, job_id: fe.job_id, class_name: fe.job&.class_name,
        created_at: fe.created_at, error: fe.error }
    }
    @failed_by_class = SolidQueue::FailedExecution
                         .joins(:job)
                         .group("solid_queue_jobs.class_name")
                         .count

    @anomaly_meetings = MeetingLedger
                          .where("hold_items @> ?", "[{\"type\":\"anomaly\"}]")
                          .order(held_at: :desc)
                          .limit(30)

    @active_stops = StopLedger.status_active.order(started_at: :desc)
    @stale_cadences = build_cadence_health.select { |h| h[:status] == :stale || h[:status] == :missing }
  rescue StandardError => e
    Rails.logger.warn("LedgersController#errors: #{e.message}")
    @failed_jobs   = []
    @failed_by_class = {}
    @anomaly_meetings = MeetingLedger.none
    @active_stops  = StopLedger.none
    @stale_cadences = []
  end

  # ⑦ 実行/テスト
  def operations
    @cadence_config = LEDGER_CADENCE_CONFIG

    @sq_stats = {
      failed:    SolidQueue::FailedExecution.count,
      scheduled: (SolidQueue::ScheduledExecution.count rescue 0),
      jobs_1h:   SolidQueue::Job.where("created_at > ?", 1.hour.ago).count
    }

    @recent_cadence_jobs = LEDGER_CADENCE_CONFIG.map do |cfg|
      rows, fail_cnt = fetch_recent_ledger_jobs(cfg[:job_class])
      cfg.merge(job_rows: rows, fail_count: fail_cnt)
    end
  rescue StandardError => e
    Rails.logger.warn("LedgersController#operations: #{e.message}")
  end

  # POST: cadence ジョブを即時 enqueue
  def run_job
    job_class_name = params[:job_class].to_s.strip
    allowed = LEDGER_CADENCE_CONFIG.map { |c| c[:job_class] }
    unless allowed.include?(job_class_name)
      redirect_to admin_ops_ledger_operations_path, alert: "不正なジョブクラス: #{job_class_name}"
      return
    end

    klass = job_class_name.constantize
    klass.perform_later
    redirect_to admin_ops_ledger_operations_path, notice: "#{job_class_name} をエンキューしました"
  rescue NameError
    redirect_to admin_ops_ledger_operations_path, alert: "ジョブクラスが見つかりません: #{job_class_name}"
  end

  private

  def build_alert_summary(service_id: nil)
    scope_tickets = service_id ? TicketLedger.where(service_id: service_id) : TicketLedger
    scope_stops   = service_id ? StopLedger.status_active.where(service_id: service_id) : StopLedger.status_active
    {
      waiting_review: scope_tickets.ticket_type_improvement.status_waiting_review.count,
      overdue:        scope_tickets.status_overdue.count,
      non_approval:   AuditDecisionLedger.non_approvals.count,
      active_stop:    scope_stops.count
    }
  rescue StandardError => e
    Rails.logger.warn("LedgersController#build_alert_summary: #{e.message}")
    {}
  end

  def build_alert_summary_extended
    base = build_alert_summary
    base.merge(
      failed_jobs_1h: SolidQueue::FailedExecution.where("solid_queue_failed_executions.created_at > ?", 1.hour.ago).count
    )
  rescue StandardError
    base || {}
  end

  def build_cadence_health(service_filter: nil)
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
    Rails.logger.warn("LedgersController#build_cadence_health: #{e.message}")
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
    Rails.logger.warn("LedgersController#build_service_overview: #{e.message}")
    {}
  end

  def build_service_data(service_id)
    svc_ledger   = ServiceLedger.find_by(service_id: service_id)
    kpis         = KpiLedger.where(service_id: service_id).order(:kpi_key)
    open_tickets = TicketLedger
                     .where(service_id: service_id)
                     .where(status: [ TicketLedger.statuses[:waiting_review], TicketLedger.statuses[:overdue] ])
                     .count
    experiments  = ExperimentLedger.where(service_id: service_id).status_active.count
    next_hb      = ServiceHeartbeat
                     .status_active
                     .where(service_id: service_id)
                     .where.not(next_run_at: nil)
                     .where("next_run_at > ?", Time.current)
                     .order(:next_run_at)
                     .includes(:meeting_definition)
                     .first
    last_meeting = MeetingLedger.where(service_id: service_id).order(held_at: :desc).first
    {
      service_id:    service_id,
      service_ledger: svc_ledger,
      kpis:          kpis,
      open_tickets:  open_tickets,
      experiments:   experiments,
      next_heartbeat: next_hb,
      last_meeting:  last_meeting
    }
  rescue StandardError => e
    Rails.logger.warn("LedgersController#build_service_data(#{service_id}): #{e.message}")
    { service_id: service_id }
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
