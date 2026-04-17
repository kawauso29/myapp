module Hr
  # Phase 38b / §19: 人事評価ロジック。
  #
  # §19 の 5 評価軸（0.0〜1.0）を TicketLedger / MeetingLedger から計算し、
  # HrEvaluationLedger に記録する。
  #
  # 評価軸:
  #   - artifact_quality: effectiveness_score の平均
  #   - kpi_contribution: linked_kpis を持つ completed ticket の比率
  #   - execution_efficiency: 期限内完了率（SLA breach を減点）
  #   - collaboration: meeting への参加率（role_fill_rate 由来）
  #   - sustainability: overdue ticket の少なさ
  #
  # 総合スコア = 各軸（nil は除外）の平均。
  #
  # 使い方:
  #   Hr::Evaluator.call(subject_role: "service_lead", service_id: "ai_sns",
  #                      period_start: q_start, period_end: q_end)
  class Evaluator
    AXES = %i[artifact_quality kpi_contribution execution_efficiency collaboration sustainability].freeze

    Result = Struct.new(:evaluation, :scores, keyword_init: true)

    def self.call(**args)
      new(**args).call
    end

    def initialize(subject_role:, period_start:, period_end:,
                   service_id: nil, scope_level: :service, subject_agent: nil,
                   source_meeting: nil, idempotency_key: nil)
      @subject_role = subject_role.to_s
      @subject_agent = subject_agent
      @service_id = service_id
      @scope_level = scope_level.to_sym
      @period_start = period_start
      @period_end = period_end
      @source_meeting = source_meeting
      @idempotency_key = idempotency_key || build_idempotency_key
    end

    def call
      scores = compute_axes
      overall = scores.values.compact.then { |vals| vals.any? ? (vals.sum / vals.size.to_f).round(4) : nil }

      evaluation = HrEvaluationLedger.find_or_initialize_by(idempotency_key: @idempotency_key)
      evaluation.assign_attributes(
        subject_role: @subject_role,
        subject_agent: @subject_agent,
        scope_level: @scope_level,
        service_id: @service_id,
        period_start: @period_start,
        period_end: @period_end,
        score: overall,
        status: :reviewed,
        evidence: evidence_payload(scores),
        criteria: AXES.each_with_object({}) { |axis, h| h[axis.to_s] = (1.0 / AXES.size).round(4) },
        source_meeting: @source_meeting
      )
      evaluation.save!

      Result.new(evaluation: evaluation, scores: scores)
    end

    private

    def build_idempotency_key
      "hr:#{@subject_role}:#{@service_id || 'global'}:#{@period_start}:#{@period_end}"
    end

    def tickets_scope
      scope = TicketLedger.where(created_at: @period_start.beginning_of_day..@period_end.end_of_day)
      scope = scope.where(service_id: @service_id) if @service_id.present?
      scope = scope.where(owner_dept: @subject_role).or(scope.where(assignee: @subject_role))
      scope
    end

    def compute_axes
      tickets = tickets_scope.to_a

      {
        artifact_quality: axis_artifact_quality(tickets),
        kpi_contribution: axis_kpi_contribution(tickets),
        execution_efficiency: axis_execution_efficiency(tickets),
        collaboration: axis_collaboration,
        sustainability: axis_sustainability(tickets)
      }
    end

    def axis_artifact_quality(tickets)
      scored = tickets.reject { |t| t.effectiveness_score.blank? }
      return nil if scored.empty?

      avg = scored.sum { |t| t.effectiveness_score.to_f } / scored.size.to_f
      clamp(avg)
    end

    def axis_kpi_contribution(tickets)
      completed = tickets.select { |t| t.status.to_s == "completed" }
      return nil if completed.empty?

      with_kpi = completed.count { |t| Array(t.linked_kpis).any? }
      clamp(with_kpi.to_f / completed.size.to_f)
    end

    def axis_execution_efficiency(tickets)
      resolved = tickets.select { |t| %w[completed cancelled approved].include?(t.status.to_s) }
      return nil if resolved.empty?

      breached = resolved.count { |t| t.sla_breached_at.present? }
      clamp(1.0 - (breached.to_f / resolved.size.to_f))
    end

    def axis_collaboration
      meetings = MeetingLedger
                   .where(scope_level: MeetingLedger.scope_levels[@scope_level.to_s])
                   .where(service_id: @service_id)
                   .where(held_at: @period_start.beginning_of_day..@period_end.end_of_day)
      return nil if meetings.empty?

      rates = meetings.map { |m| m.role_fill_rate&.to_f }.compact
      return nil if rates.empty?

      clamp(rates.sum / rates.size.to_f)
    end

    def axis_sustainability(tickets)
      return nil if tickets.empty?

      overdue = tickets.count { |t| t.status.to_s == "overdue" }
      clamp(1.0 - (overdue.to_f / tickets.size.to_f))
    end

    def clamp(value)
      return nil if value.nil?
      [ [ value.to_f, 0.0 ].max, 1.0 ].min.round(4)
    end

    def evidence_payload(scores)
      {
        axes: scores.transform_keys(&:to_s),
        sampled_at: Time.current.iso8601,
        service_id: @service_id,
        subject_agent: @subject_agent
      }.compact
    end
  end
end
