module Ledgers
  # Phase 31c: Runner（WeeklyDept / MonthlyOps / QuarterlyReview / AnnualPlan）の成果物を
  # `ArtifactLedger` に自動記録するためのヘルパ。
  #
  # Runner の末尾で `Ledgers::RunnerArtifactPublisher.publish_for!(meeting: ..., runner: :weekly_dept, ...)`
  # を呼び出すと、会議の議事要約（decisions / tickets_to_create / directives）を
  # `artifact_type: :execution_plan` として台帳に記録する。
  #
  # `idempotency_key` を会議の `idempotency_key` から派生させて二重記録を防ぐ。
  # 同じ会議で再実行された場合も同一 title で supersede チェーンに繋がる。
  class RunnerArtifactPublisher
    # runner 識別子ごとの artifact タイトル接頭辞
    TITLE_PREFIXES = {
      daily: "Daily Summary",
      weekly_dept: "Weekly Dept Minutes Summary",
      ui_check: "UI Check Minutes Summary",
      monthly_ops: "Monthly Ops Minutes Summary",
      quarterly_review: "Quarterly Review Summary",
      annual_plan: "Annual Plan Summary"
    }.freeze

    def self.publish_for!(meeting:, runner:, service_id: nil, source_ticket: nil, extra_content: {})
      new(meeting: meeting, runner: runner, service_id: service_id,
          source_ticket: source_ticket, extra_content: extra_content).call
    end

    def initialize(meeting:, runner:, service_id: nil, source_ticket: nil, extra_content: {})
      @meeting = meeting
      @runner = runner.to_sym
      @service_id = service_id
      @source_ticket = source_ticket
      @extra_content = extra_content || {}
    end

    def call
      title = build_title
      content = {
        meeting_id: @meeting.id,
        meeting_key: @meeting.meeting_key,
        meeting_type: @meeting.meeting_type,
        held_at: @meeting.held_at&.iso8601,
        role_fill_rate: @meeting.role_fill_rate,
        participants: @meeting.participants,
        decisions: @meeting.decisions,
        tickets_to_create: @meeting.tickets_to_create,
        escalations: @meeting.escalations,
        directives: @meeting.directives,
        hold_items: @meeting.hold_items,
        carry_over_items: @meeting.carry_over_items
      }.merge(@extra_content.symbolize_keys).compact

      Artifacts::Publisher.publish(
        artifact_type: :execution_plan,
        title: title,
        scope_level: scope_level,
        service_id: @service_id,
        content: content,
        source_meeting: @meeting,
        source_ticket: @source_ticket,
        author: "#{@runner}_runner",
        idempotency_key: idempotency_key
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # 二重記録や同一 version 競合はログだけ残して runner 処理を止めない
      Rails.logger.warn("[RunnerArtifactPublisher] skipped publish for meeting=#{@meeting.id} runner=#{@runner}: #{e.message}")
      nil
    end

    private

    def build_title
      prefix = TITLE_PREFIXES.fetch(@runner, "Runner Output")
      case @runner
      when :daily, :weekly_dept, :ui_check
        "#{prefix} (#{@service_id})"
      else
        prefix
      end
    end

    def scope_level
      case @runner
      when :daily, :weekly_dept, :ui_check
        :service
      else
        :company
      end
    end

    def idempotency_key
      return nil if @meeting.idempotency_key.blank?

      "artifact:#{@runner}:#{@meeting.idempotency_key}"
    end
  end
end
