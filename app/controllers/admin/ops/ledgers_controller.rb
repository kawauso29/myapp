class Admin::Ops::LedgersController < Admin::Ops::BaseController
  LEDGER_CADENCE_CONFIG = [
    { cadence: :daily,     meeting_key: "daily",            job_class: "DailyLedgerRunJob",           interval: 30.minutes },
    { cadence: :weekly,    meeting_key: "weekly_dept",      job_class: "WeeklyDeptLedgerRunJob",      interval: 4.hours    },
    { cadence: :monthly,   meeting_key: "monthly_ops",      job_class: "MonthlyOpsLedgerRunJob",      interval: 12.hours   },
    { cadence: :quarterly, meeting_key: "quarterly_review", job_class: "QuarterlyReviewLedgerRunJob", interval: 2.days     },
    { cadence: :annual,    meeting_key: "annual_plan",      job_class: "AnnualPlanLedgerRunJob",      interval: 7.days     }
  ].freeze

  LEDGER_SERVICES = %w[ai_sns trading picro].freeze
  ROLE_SUMMARY_FALLBACK = "この役割の概要は未設定です。".freeze
  ROLE_PROFILE_BY_KEY = {
    "ceo" => {
      display_name: "社長",
      summary: "理念整合を守りながら、全社の最終意思決定と長期戦略を担う経営責任者。",
      responsibilities: [
        "理念と長期ビジョンの維持",
        "全社ポートフォリオの最終判断",
        "緊急時の最終指揮",
        "主要KPIと収益責任の監督"
      ],
      tasks: [
        "年次・四半期の方針決定",
        "重大リスク時の是正判断",
        "役員層への優先順位提示",
        "長期KPIの達成状況レビュー"
      ]
    },
    "cto" => {
      display_name: "CTO",
      summary: "技術戦略と実装基盤の責任者として、速度・品質・コストの最適化を統括する。",
      responsibilities: [
        "技術戦略の策定と更新",
        "開発生産性と品質の両立",
        "AI/サーバーコストの最適化",
        "技術負債の管理方針策定"
      ],
      tasks: [
        "技術ロードマップの策定",
        "アーキテクチャ判断と標準化",
        "運用指標のモニタリング",
        "技術的リスクの早期是正"
      ]
    },
    "executive_planning" => {
      display_name: "役員（企画）",
      summary: "理念を市場価値と体験価値へ翻訳し、中期施策へ接続する責任者。",
      responsibilities: [
        "市場機会の整理と優先順位化",
        "体験価値仮説の定義",
        "中期KPI設計",
        "事業部要求の整理"
      ],
      tasks: [
        "仮説検証テーマの設計",
        "企画会議アジェンダの提示",
        "サービス横断の整合調整",
        "ロードマップ更新"
      ]
    },
    "executive_development" => {
      display_name: "役員（開発）",
      summary: "企画要求を継続可能な技術実装へ変換し、運用品質を担保する責任者。",
      responsibilities: [
        "開発組織の実行優先順位管理",
        "品質・可用性の維持",
        "開発効率の継続改善",
        "実装制約の可視化"
      ],
      tasks: [
        "重要案件の実装判断",
        "リリース品質のゲート管理",
        "障害再発防止の推進",
        "技術改善の投資配分調整"
      ]
    },
    "executive_audit" => {
      display_name: "役員（監査）",
      summary: "理念・安全性・整合性の監督を担い、重大リスクを未然に防ぐ責任者。",
      responsibilities: [
        "理念逸脱リスクの監査",
        "KPI整合性の監査",
        "重大インシデントの統制",
        "停止/再開判断の監督"
      ],
      tasks: [
        "監査論点の定義と更新",
        "承認ログと差し戻し理由の監視",
        "緊急停止時の判断支援",
        "是正完了の確認"
      ]
    },
    "executive_hr" => {
      display_name: "役員（人事）",
      summary: "組織性能を継続改善するため、評価・配置・再編の方針を統括する責任者。",
      responsibilities: [
        "組織健全性の維持",
        "評価制度の運用監督",
        "配置最適化の方針策定",
        "組織再編判断の支援"
      ],
      tasks: [
        "評価サイクルのレビュー",
        "人員配置案の作成支援",
        "再編提案の妥当性確認",
        "能力開発課題の優先順位化"
      ]
    },
    "business_owner" => {
      display_name: "事業責任者",
      summary: "担当サービスの売上・利益・体験価値に対して直接責任を持つ経営責任者。",
      responsibilities: [
        "サービス別KPI達成責任",
        "収益性と成長性の両立",
        "優先順位の最終決定",
        "共通部門への要求定義"
      ],
      tasks: [
        "週次の事業進捗レビュー",
        "改善テーマの意思決定",
        "撤退/拡大の一次提案",
        "重要課題のエスカレーション"
      ]
    },
    "planning" => {
      display_name: "企画部",
      summary: "ユーザー価値と市場機会を設計し、施策を実行可能な計画へ落とし込む部門。",
      responsibilities: [
        "市場・顧客分析",
        "体験価値仮説の設計",
        "施策要件の定義",
        "ロードマップ策定支援"
      ],
      tasks: [
        "仮説検証の設計",
        "要件定義ドキュメント作成",
        "優先度案の提示",
        "会議向け論点整理"
      ]
    },
    "dev" => {
      display_name: "開発部",
      summary: "企画を高品質な実装へ変換し、安定運用と継続改善を担う実行部門。",
      responsibilities: [
        "技術設計と実装",
        "テストと品質保証",
        "デプロイと運用改善",
        "技術負債管理"
      ],
      tasks: [
        "仕様に基づく開発実行",
        "不具合修正と再発防止",
        "運用監視と性能改善",
        "技術記録の更新"
      ]
    },
    "audit" => {
      display_name: "監査部",
      summary: "理念・安全性・KPI整合を守るために、監査と差し戻し判断を担う統制部門。",
      responsibilities: [
        "理念整合監査",
        "セキュリティ監査",
        "リスク分類と評価",
        "承認/差し戻し判断"
      ],
      tasks: [
        "監査観点の定期見直し",
        "非承認案件の追跡",
        "重大リスクの即時通知",
        "改善完了の監査"
      ]
    },
    "cs" => {
      display_name: "顧客成功部",
      summary: "顧客接点から得た知見を運用と開発へ還流し、体験品質を高める部門。",
      responsibilities: [
        "問い合わせ対応品質の維持",
        "FAQ/ヘルプ資産の整備",
        "VOC分析と示唆抽出",
        "顧客知見の社内展開"
      ],
      tasks: [
        "問い合わせ傾向の分析",
        "改善要求の起票",
        "リリース案内の運用",
        "顧客理解不足の解消提案"
      ]
    },
    "system" => {
      display_name: "システム（自動運用）",
      summary: "会議なしの日次監視・異常検知・速報生成を自動で実行する運用ロール。",
      responsibilities: [
        "日次KPIスナップショット取得",
        "異常の早期検知",
        "定期ジョブの安定実行",
        "運用ログの記録"
      ],
      tasks: [
        "DailyRunnerの実行",
        "Heartbeat監視",
        "異常検知結果の通知",
        "定期実行の健全性チェック"
      ]
    }
  }.freeze

  # ① ダッシュボード or cadence/service 別実行一覧
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
    @time_axis_rows = build_time_axis_rows
  rescue StandardError => e
    Rails.logger.warn("LedgersController#schedule: #{e.message}")
    @time_axis_rows ||= []
  end

  # ③-2 圧縮時間軸の手動更新
  def update_time_axis
    service_id = params[:service_id].to_s.strip
    cadence = params[:cadence].to_s
    interval_seconds_raw = params[:interval_seconds].to_s.strip
    description = params[:description].to_s.strip

    unless LEDGER_SERVICES.include?(service_id)
      redirect_to admin_ops_ledger_schedule_path, alert: "不明なサービス: #{service_id.presence || '(blank)'}"
      return
    end

    unless ServiceTimeAxisSetting.cadences.key?(cadence)
      redirect_to admin_ops_ledger_schedule_path, alert: "不正な cadence: #{cadence.presence || '(blank)'}"
      return
    end

    unless interval_seconds_raw.match?(/\A[1-9]\d*\z/)
      redirect_to admin_ops_ledger_schedule_path, alert: "interval_seconds は 1 以上の整数で指定してください"
      return
    end

    setting = ServiceTimeAxisSetting.find_or_initialize_by(service_id:, cadence:)
    setting.interval_seconds = interval_seconds_raw.to_i
    setting.description = description.presence
    setting.save!

    refresh_heartbeat_next_run!(service_id:, cadence:, interval_seconds: setting.interval_seconds)
    redirect_to admin_ops_ledger_schedule_path,
                notice: "圧縮期間を更新しました: #{service_id} / #{cadence} = #{human_interval_label(setting.interval_seconds)}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_ops_ledger_schedule_path, alert: "更新に失敗しました: #{e.record.errors.full_messages.join(', ')}"
  end

  # ④ 各部毎の情報
  def departments
    @roles_by_category = OrganizationRole.active.order(:category, :role_key).group_by(&:category)
    @meeting_def_counts = MeetingDefinition.group(:chair_role).count
    @hr_eval_counts     = HrEvaluationLedger.group(:subject_role).count
    @org_change_counts  = OrgChangeLedger.group(:scope_level).count
    @role_profiles_by_key = {}
    @roles_by_category.each_value do |roles|
      roles.each do |role|
        @role_profiles_by_key[role.role_key] = role_profile_for(role)
      end
    end
  rescue StandardError => e
    Rails.logger.warn("LedgersController#departments: #{e.message}")
    @roles_by_category ||= {}
    @meeting_def_counts ||= {}
    @hr_eval_counts ||= {}
    @org_change_counts ||= {}
    @role_profiles_by_key ||= {}
  end

  def department_detail
    @role = OrganizationRole.find_by!(role_key: params[:role_key])
    @role_profile = role_profile_for(@role)

    @chaired_defs   = MeetingDefinition.where(chair_role: @role.role_key)
    @participant_defs = MeetingDefinition
                          .where("participant_roles @> ?", [ @role.role_key ].to_json)
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
    cfg = LEDGER_CADENCE_CONFIG.find { |c| c[:job_class] == job_class_name }
    unless cfg
      redirect_to admin_ops_ledger_operations_path, alert: "不正なジョブクラス: #{job_class_name}"
      return
    end

    klass = cfg[:job_class].constantize
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

  def role_profile_for(role)
    profile = ROLE_PROFILE_BY_KEY[role.role_key] || {}
    {
      display_name: profile[:display_name].presence || role.display_name,
      summary: profile[:summary].presence || role.description.presence || ROLE_SUMMARY_FALLBACK,
      responsibilities: Array(profile[:responsibilities]).presence || default_responsibilities_for(role),
      tasks: Array(profile[:tasks]).presence || default_tasks_for(role)
    }
  end

  def default_responsibilities_for(role)
    [
      "#{role.display_name}領域の運用品質を維持する",
      "関連会議での論点整理と意思決定を支援する",
      "担当領域のKPI進捗を継続監視する"
    ]
  end

  def default_tasks_for(role)
    [
      "定例会議のインプット更新",
      "改善タスクの優先度見直し",
      "未完了チケットのフォローアップ"
    ]
  end

  def build_time_axis_rows
    services = LEDGER_SERVICES
    cadences = Ledgers::TimeAxis::CADENCES
    existing = ServiceTimeAxisSetting.where(service_id: services, cadence: cadences).index_by { |s| [ s.service_id, s.cadence ] }

    services.flat_map do |service_id|
      cadences.map do |cadence|
        cadence_key = cadence.to_s
        setting = existing[[ service_id, cadence_key ]]
        default_seconds = Ledgers::TimeAxis::INTERVALS.fetch(cadence).to_i
        current_seconds = setting&.interval_seconds || default_seconds

        {
          service_id: service_id,
          cadence: cadence_key,
          interval_seconds: current_seconds,
          interval_label: human_interval_label(current_seconds),
          default_seconds: default_seconds,
          default_label: human_interval_label(default_seconds),
          source: setting ? "db" : "default",
          description: setting&.description.to_s
        }
      end
    end
  rescue StandardError => e
    Rails.logger.warn("LedgersController#build_time_axis_rows: #{e.message}")
    []
  end

  def human_interval_label(seconds)
    sec = seconds.to_i
    return "#{sec / 1.day}日" if sec.positive? && (sec % 1.day).zero?
    return "#{sec / 1.hour}時間" if sec.positive? && (sec % 1.hour).zero?
    return "#{sec / 1.minute}分" if sec.positive? && (sec % 1.minute).zero?

    "#{sec}秒"
  end

  def refresh_heartbeat_next_run!(service_id:, cadence:, interval_seconds:)
    interval_sec = interval_seconds.to_i
    return unless interval_sec.positive?

    heartbeat_scope = ServiceHeartbeat.status_active.where(service_id:, due_cycle: cadence)
    return if heartbeat_scope.none?

    now = Time.current
    next_run_at = now + interval_sec.seconds

    heartbeat_scope.find_each do |heartbeat|
      heartbeat.update!(next_run_at:)
    end
  end
end
