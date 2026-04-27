module Ledgers
  class WeeklyDeptRunner
    def self.call(service_id:, ticket_inputs: nil, present_roles: nil, meeting_key: "weekly_dept", use_daily_anomalies: true)
      new(service_id:, ticket_inputs:, present_roles:, meeting_key:, use_daily_anomalies:).call
    end

    def initialize(service_id:, ticket_inputs: nil, present_roles: nil, meeting_key: "weekly_dept", use_daily_anomalies: true)
      @service_id = service_id
      raw_inputs = ticket_inputs.presence || default_ticket_inputs
      @ticket_inputs = raw_inputs.map(&:symbolize_keys)
      @present_roles = present_roles
      @meeting_key = meeting_key
      @use_daily_anomalies = use_daily_anomalies
    end

    def call
      definition = meeting_definition!
      preflight = Ledgers::PreflightValidator.call(definition:, present_roles: @present_roles)
      meeting = MeetingLedger.create!(
        meeting_definition: definition,
        meeting_key: definition.meeting_key,
        meeting_type: definition.meeting_type,
        scope_level: definition.scope_level,
        service_id:,
        chair: definition.chair_role,
        participants: preflight.participants,
        role_fill_rate: preflight.role_fill_rate,
        held_at: Time.current,
        status: :open,
        idempotency_key: Ledgers::IdempotencyKey.for_meeting(
          prefix: @meeting_key,
          parts: [ service_id ],
          cadence: :weekly
        )
      )

      created = []
      hold_items = []
      escalations = []
      decisions = []

      entry_check = Stops::EntryGuard.check(scope_level: :service, service_id:)

      all_ticket_inputs = memoized_all_ticket_inputs

      all_ticket_inputs.each do |input|
        attrs = input
        linked_kpis = Array(attrs[:linked_kpis]).compact
        if linked_kpis.blank?
          hold_items << hold_payload(attrs)
          decisions << { title: attrs[:title], result: "held_for_missing_kpis" }
          next
        end

        missing_kpi_keys = missing_kpi_keys(linked_kpis)
        if missing_kpi_keys.present?
          hold_items << hold_payload(attrs, reason: "missing_kpi_definition", missing_kpi_keys:)
          decisions << { title: attrs[:title], result: "held_for_missing_kpi_definition" }
          next
        end

        if entry_check.blocked?
          hold_items << hold_payload(attrs, reason: "entry_guard_blocked")
          decisions << { title: attrs[:title], result: "held_for_active_stop" }
          next
        end

        # デフォルトプレースホルダーチケットが既にアクティブな場合は重複作成しない。
        # キャッシュクリア後の再起動等で同スロットのジョブが再実行されても安全。
        if default_ticket_active?(attrs[:title])
          decisions << { title: attrs[:title], result: "skipped_duplicate_default" }
          next
        end

        begin
          ticket = create_ticket!(meeting:, attrs:)
        rescue ActiveRecord::RecordNotSaved => e
          reason = ticket_blocked_reason(e.record)
          hold_items << hold_payload(attrs, reason:)
          decisions << { title: attrs[:title], result: "held_for_#{reason}" }
          next
        end
        created << { ticket_id: ticket.id, title: ticket.title, status: ticket.status }
        decisions << { ticket_id: ticket.id, result: ticket.status }

        next unless ticket.status_waiting_review?

        escalations << {
          ticket_id: ticket.id,
          escalation_to: ticket.escalation_to,
          reason: "weekly_audit_block"
        }
      end

      detector_result = Ledgers::ImprovementDetector.call
      resolver_result = Ledgers::ImprovementResolver.call
      improvements = {
        detected: detector_result.fetch(:detected, 0),
        resolved: resolver_result.fetch(:resolved, 0),
        details: Array(detector_result.fetch(:details, [])) + Array(resolver_result.fetch(:details, []))
      }

      planned_ai_sns = advance_ai_sns_plan_approved!

      meeting.update!(
        decisions: decisions + planned_ai_sns,
        hold_items:,
        carry_over_items: hold_items,
        tickets_to_create: created,
        escalations:,
        directives: [ { improvements: } ],
        minutes: Ledgers::MinutesGenerator.for_weekly(
          service_id:  service_id,
          decisions:   decisions + planned_ai_sns,
          hold_items:  hold_items,
          improvements: improvements,
          escalations: escalations
        ),
        status: :closed
      )

      # Phase 31c: 会議の議事要約を成果物台帳に自動記録する
      Ledgers::RunnerArtifactPublisher.publish_for!(
        meeting: meeting,
        runner: @meeting_key.to_sym,
        service_id: service_id
      )

      # Phase 45a: 週次会議後に tech_record ドラフトを自動生成する
      publish_weekly_tech_record!(meeting:)

      # Phase 45b: 週次会議後に customer_notice（顧客向けリリースノート）ドラフトを自動生成する
      publish_weekly_customer_notice_draft!(meeting:)

      # Phase 45c: dev / audit 向け KnowledgeLedger（ADR/Runbook）未作成警告
      check_and_warn_missing_knowledge_entry!(meeting:)

      meeting
    end

    private

    attr_reader :service_id, :ticket_inputs

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: @meeting_key, scope_level: :service)
    end

    def default_ticket_inputs
      [
        {
          ticket_type: "operations",
          title: "#{@meeting_key} default ticket for #{service_id}",
          linked_kpis: [ "kpi:service_health" ],
          audit_ok: true,
          owner_dept: "planning",
          owner_agent: "#{@meeting_key}_runner"
        }
      ]
    end

    # デフォルトプレースホルダーチケットが既に active（未完了・未キャンセル）かチェックする。
    # TicketLedger::DEFAULT_TICKET_TITLE_PATTERN に一致するタイトルに限定し、
    # 実ビジネスチケット（title がユーザー定義）への誤抑制を防ぐ。
    # DB 側は大文字小文字を区別するため ILIKE を使い case-insensitive に検索する。
    def default_ticket_active?(title)
      return false unless title.to_s.match?(TicketLedger::DEFAULT_TICKET_TITLE_PATTERN)

      TicketLedger
        .where("LOWER(title) = LOWER(?)", title)
        .where(service_id:, due_cycle: :weekly)
        .where.not(status: %w[completed cancelled])
        .exists?
    end

    def create_ticket!(meeting:, attrs:)
      audit_ok = attrs.fetch(:audit_ok, true)
      TicketLedger.create!(
        ticket_type: attrs.fetch(:ticket_type, "operations"),
        title: attrs.fetch(:title),
        scope_level: :service,
        service_id:,
        business_owner: attrs[:business_owner],
        source_meeting_type: :weekly,
        source_meeting: meeting,
        owner_dept: attrs[:owner_dept],
        owner_agent: attrs[:owner_agent],
        linked_kpis: attrs[:linked_kpis],
        linked_artifacts: attrs[:linked_artifacts] || [],
        priority: attrs[:priority] || :medium,
        status: audit_ok ? :approved : :waiting_review,
        assignee: service_id,
        due_date: Ledgers::TimeAxis.due_date_for(:weekly),
        due_cycle: :weekly,
        escalation_to: audit_ok ? nil : :monthly,
        # Phase 44e: Runner が生成する運用チケットは template 不要（Copilot 入力ではない）
        skip_template_guard: true
      )
    end

    def ticket_blocked_reason(record)
      return "callback_blocked" unless record.is_a?(TicketLedger)

      base_msgs = record.errors.full_messages
      if base_msgs.any? { |m| m.include?("lane capacity exceeded") }
        "lane_capacity_exceeded"
      else
        "callback_blocked"
      end
    end

    # Phase 46: monthly_ops で approved になった ai_sns_plan チケットを
    # 週次会議で確認し planned に昇格させる（approved → planned）。
    # これにより MeetingLedger に週次確認の記録が残り、governance が完成する。
    def advance_ai_sns_plan_approved!
      advanced = []
      TicketLedger.ai_sns_plan.status_approved.find_each do |ticket|
        ticket.update!(
          status: :planned,
          due_date: ticket.due_date || Ledgers::TimeAxis.due_date_for(:weekly)
        )
        advanced << { ticket_id: ticket.id, title: ticket.title, result: "planned" }
      end
      advanced
    end

    def hold_payload(attrs, reason: "missing_linked_kpis", missing_kpi_keys: nil)
      {
        title: attrs[:title],
        reason:,
        missing_kpi_keys:,
        next_cycle: "weekly"
      }.compact
    end

    def memoized_all_ticket_inputs
      @memoized_all_ticket_inputs ||= ticket_inputs + daily_anomaly_inputs
    end

    def missing_kpi_keys(linked_kpis)
      linked_kpis - existing_kpi_keys
    end

    def existing_kpi_keys
      @existing_kpi_keys ||= begin
        requested_kpi_keys = memoized_all_ticket_inputs.flat_map { |input| Array(input[:linked_kpis]).compact }.uniq
        if requested_kpi_keys.blank?
          []
        else
          KpiLedger.where(kpi_key: requested_kpi_keys).pluck(:kpi_key)
        end
      end
    end

    def daily_anomaly_inputs
      return [] unless @use_daily_anomalies

      @daily_anomaly_inputs ||= fetch_daily_anomaly_inputs
    end

    def fetch_daily_anomaly_inputs
      latest_daily = MeetingLedger
                       .where(meeting_type: :daily, service_id: @service_id)
                       .order(held_at: :desc)
                       .first
      return [] unless latest_daily

      existing_titles = ticket_inputs.map { |i| i[:title].to_s }

      Array(latest_daily.hold_items)
        .select { |item| (item["type"] || item[:type]).to_s == "anomaly" }
        .filter_map do |item|
          kpi_key = (item["kpi_key"] || item[:kpi_key]).to_s
          next if kpi_key.blank?

          anomaly_title = "Anomaly: #{kpi_key}"
          next if existing_titles.include?(anomaly_title)

          {
            ticket_type: "operations",
            title: anomaly_title,
            linked_kpis: [ kpi_key ],
            audit_ok: false,
            owner_dept: "system",
            owner_agent: "daily_runner"
          }
        end
    end

    # ---- Phase 45 additions ----

    KNOWLEDGE_CHECK_DAYS = 14

    # 週次会議後に tech_record（内部向け作業メモ）ドラフトを自動生成する。
    # meeting.idempotency_key を使った idempotency_key で二重作成を防ぐ。
    def publish_weekly_tech_record!(meeting:)
      ikey = "draft:tech_record:weekly_dept:#{service_id}:#{meeting.idempotency_key}"
      return if ArtifactLedger.exists?(idempotency_key: ikey)

      week_label = Date.current.beginning_of_week(:monday).iso8601
      title      = "Weekly Tech Record (#{service_id}) #{week_label}"
      return if ArtifactLedger.exists?(artifact_type: :tech_record, title: title)

      ArtifactLedger.create!(
        artifact_type: :tech_record,
        scope_level: :service,
        service_id: service_id,
        title: title,
        artifact_version: 1,
        content: {
          meeting_id: meeting.id,
          held_at: meeting.held_at.iso8601,
          tickets_created: meeting.tickets_to_create,
          decisions: meeting.decisions,
          note: "Auto-generated draft. Review and edit as needed."
        },
        status: :draft,
        source_meeting: meeting,
        author: "weekly_dept_runner",
        idempotency_key: ikey
      )
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[WeeklyDeptRunner] publish_weekly_tech_record! skipped: #{e.message}")
    end

    # 週次会議後に customer_notice（顧客向けリリースノート）ドラフトを自動生成する。
    #
    # tech_record（内部向け）と対になる外部向け成果物として、
    # 会議が開催されるたびに毎回生成する。フィードバック件数には依存しない。
    # 内容は「今週の承認済みチケット一覧」で、CS チームが編集・公開する前提のドラフト。
    def publish_weekly_customer_notice_draft!(meeting:)
      ikey = "draft:customer_notice:weekly_dept:#{service_id}:#{meeting.idempotency_key}"
      return if ArtifactLedger.exists?(idempotency_key: ikey)

      week_label = Date.current.beginning_of_week(:monday).iso8601
      title      = "Customer Notice Draft (#{service_id}) #{week_label}"
      return if ArtifactLedger.exists?(artifact_type: :customer_notice, title: title)

      approved_tickets = Array(meeting.tickets_to_create).select do |t|
        t["status"].to_s == "approved"
      end

      ArtifactLedger.create!(
        artifact_type: :customer_notice,
        scope_level: :service,
        service_id: service_id,
        title: title,
        artifact_version: 1,
        content: {
          meeting_id: meeting.id,
          held_at: meeting.held_at.iso8601,
          approved_tickets: approved_tickets,
          note: "Auto-generated draft. Review approved tickets above and publish as a release note for customers."
        },
        status: :draft,
        source_meeting: meeting,
        author: "weekly_dept_runner",
        idempotency_key: ikey
      )
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[WeeklyDeptRunner] publish_weekly_customer_notice_draft! skipped: #{e.message}")
    end

    # 過去 KNOWLEDGE_CHECK_DAYS 日間に ADR または Runbook が作成されていなければ
    # KnowledgeLedger に警告ドラフトエントリを作成する。
    # service_id スコープの MeetingLedger に source_meeting が紐付いた KnowledgeLedger を優先チェックし、
    # 存在しない場合は service_id 関連の MeetingLedger から参照されたエントリを確認する。
    def check_and_warn_missing_knowledge_entry!(meeting:)
      return if KnowledgeLedger
                  .where(kind: %i[adr runbook])
                  .where(created_at: KNOWLEDGE_CHECK_DAYS.days.ago..)
                  .where(source_meeting_id: service_meeting_ids)
                  .exists?

      ikey = "knowledge_warn:weekly_dept:#{service_id}:#{meeting.idempotency_key}"
      return if KnowledgeLedger.exists?(idempotency_key: ikey)

      KnowledgeLedger.create!(
        kind: :runbook,
        title: "⚠️ No ADR/Runbook in #{KNOWLEDGE_CHECK_DAYS} days (#{service_id})",
        status: :draft,
        source_meeting: meeting,
        author: "weekly_dept_runner",
        body: "No ADR or Runbook has been created in the last #{KNOWLEDGE_CHECK_DAYS} days for #{service_id}. " \
              "Please document recent architectural decisions or operational procedures.",
        idempotency_key: ikey
      )
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
      Rails.logger.warn("[WeeklyDeptRunner] check_and_warn_missing_knowledge_entry! skipped: #{e.message}")
    end

    # このサービスに関連する MeetingLedger の ID を返す（knowledge check のスコープ用）
    def service_meeting_ids
      @service_meeting_ids ||= MeetingLedger.where(service_id:).pluck(:id)
    end
  end
end
