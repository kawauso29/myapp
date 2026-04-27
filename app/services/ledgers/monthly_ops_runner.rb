module Ledgers
  class MonthlyOpsRunner
    ALLOWED_RESOLUTIONS = %w[approved draft cancelled].freeze
    DEFAULT_ASSIGNEE = "monthly_ops_runner".freeze

    def self.call(resolution_map: {}, present_roles: nil)
      new(resolution_map:, present_roles:).call
    end

    def initialize(resolution_map:, present_roles: nil)
      @resolution_map = (resolution_map || {}).transform_keys(&:to_i)
      @present_roles = present_roles
    end

    def call
      definition = meeting_definition!
      preflight = Ledgers::PreflightValidator.call(definition:, present_roles: @present_roles)
      ikey = Ledgers::IdempotencyKey.for_meeting(prefix: "monthly_ops", cadence: :monthly)

      # 同一スロット内の再実行（ジョブ失敗→リトライ）で idempotency_key 重複エラーにならないよう
      # 既存会議を先に検索し、既に closed なら完了済みとして即返す。
      # open の場合は create! をスキップして既存会議を直接利用し、後続処理を継続する。
      meeting = MeetingLedger.find_by(idempotency_key: ikey)
      return meeting if meeting&.status_closed?

      unless meeting
        begin
          meeting = MeetingLedger.create!(
            meeting_definition: definition,
            meeting_key: definition.meeting_key,
            meeting_type: definition.meeting_type,
            scope_level: definition.scope_level,
            chair: definition.chair_role,
            participants: preflight.participants,
            role_fill_rate: preflight.role_fill_rate,
            held_at: Time.current,
            status: :open,
            idempotency_key: ikey
          )
        rescue ActiveRecord::RecordInvalid => e
          raise unless e.record.errors.of_kind?(:idempotency_key, :taken)

          meeting = MeetingLedger.find_by!(idempotency_key: ikey)
        end
      end

      decisions = []
      target_tickets.find_each do |ticket|
        resolution = normalize_resolution(@resolution_map[ticket.id] || "approved")
        ticket.update!(
          status: resolution,
          assignee: ticket.assignee.presence || DEFAULT_ASSIGNEE,
          due_date: ticket.due_date || Ledgers::TimeAxis.due_date_for(:monthly),
          due_cycle: resolution == "draft" ? :weekly : ticket.due_cycle,
          escalation_to: nil
        )
        decisions << { ticket_id: ticket.id, resolution: }
      end

      resolver_result = Ledgers::ImprovementResolver.call
      escalation_result = Ledgers::ImprovementEscalator.call
      improvements = {
        detected: 0,
        resolved: resolver_result.fetch(:resolved, 0),
        overdue_marked: escalation_result.fetch(:overdue_marked, 0),
        escalated_monthly: escalation_result.fetch(:escalated_monthly, 0),
        escalated_quarterly: escalation_result.fetch(:escalated_quarterly, 0),
        details: Array(resolver_result.fetch(:details, [])) + Array(escalation_result.fetch(:details, []))
      }

      # Phase 45: 月次で各部署ロール別の ArtifactLedger 発行数をまとめる
      artifact_summary = artifact_publish_summary

      monthly_minutes = Ledgers::MinutesGenerator.for_monthly(
        decisions:     decisions,
        resolved:      improvements[:resolved].to_i,
        overdue_marked: improvements.fetch(:overdue_marked, 0).to_i,
        escalated:     (improvements.fetch(:escalated_monthly, 0).to_i +
                        improvements.fetch(:escalated_quarterly, 0).to_i)
      )

      meeting.update!(decisions:, directives: [ { improvements:, artifact_summary: } ], status: :closed,
                     carry_over_items: previous_hold_items, minutes: monthly_minutes)

      # Phase 31c: 月次会議の議事要約を成果物台帳に自動記録する
      Ledgers::RunnerArtifactPublisher.publish_for!(
        meeting: meeting,
        runner: :monthly_ops,
        extra_content: { artifact_summary: }
      )

      meeting
    end

    private

    def meeting_definition!
      MeetingDefinition.find_by!(meeting_key: "monthly_ops", scope_level: :company)
    end

    def target_tickets
      TicketLedger.status_waiting_review.escalation_to_monthly
                  .or(TicketLedger.ai_sns_plan.status_draft)
    end

    def normalize_resolution(value)
      resolution = value.to_s
      return resolution if ALLOWED_RESOLUTIONS.include?(resolution)

      "approved"
    end

    # Phase 45: 月次の ArtifactLedger 発行統計（過去 30 日間）
    def artifact_publish_summary
      range = 30.days.ago..Time.current
      {
        total_published:  ArtifactLedger.status_published.where(created_at: range).count,
        total_draft:      ArtifactLedger.status_draft.where(created_at: range).count,
        by_type:          ArtifactLedger.where(created_at: range)
                                        .group(:artifact_type)
                                        .count
                                        .transform_keys { |k| ArtifactLedger.artifact_types.key(k) || k },
        knowledge_new:    KnowledgeLedger.where(created_at: range).count,
        period_start:     range.begin.iso8601,
        period_end:       range.end.iso8601
      }
    rescue StandardError => e
      Rails.logger.warn("[MonthlyOpsRunner] artifact_publish_summary error: #{e.message}")
      {}
    end

    # 補強8: 前回 weekly_dept 会議の hold_items を引き継ぐ
    def previous_hold_items
      prev = MeetingLedger.where(meeting_key: "weekly_dept")
                          .order(held_at: :desc)
                          .first
      prev&.hold_items || []
    end
  end
end
