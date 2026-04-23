class Admin::DevInitiativesController < Admin::BaseController
  # PR2: DevInitiative は read-only に格下げ。
  # 表示・更新ともに `TicketLedger.ai_sns_plan` を正本として扱う。
  # 旧 `DevInitiative` の同名項目は `Ledgers::AiSnsPlanSync` の after_save mirror で作成・更新される。
  def index
    @tickets = TicketLedger.ai_sns_plan.order(priority: :desc, idempotency_key: :asc)
    counts = TicketLedger.ai_sns_plan.group(:status).count
    @stats = {
      todo:        counts["draft"] || 0,
      in_progress: counts["executing"] || 0,
      done:        counts["completed"] || 0,
      total:       TicketLedger.ai_sns_plan.count
    }
  end

  def update
    @ticket = find_ticket!
    return redirect_back fallback_location: admin_dev_initiatives_path, alert: "対象の項目が見つかりません" unless @ticket

    @ticket.assign_attributes(ticket_params_from(params))
    apply_skip_guards(@ticket)
    if @ticket.save
      redirect_back fallback_location: admin_dev_initiatives_path,
                    notice: "[#{@ticket.ai_sns_plan_item_key}] を更新しました"
    else
      redirect_back fallback_location: admin_dev_initiatives_path,
                    alert: "更新に失敗しました: #{@ticket.errors.full_messages.join(', ')}"
    end
  end

  def update_status
    @ticket = find_ticket!
    return redirect_back fallback_location: admin_dev_initiatives_path, alert: "対象の項目が見つかりません" unless @ticket

    new_status = params[:status].to_s
    case new_status
    when "in_progress"
      @ticket.assign_attributes(status: :executing)
    when "done"
      @ticket.assign_attributes(status: :completed, due_date: Date.current)
    when "todo"
      @ticket.assign_attributes(status: :draft, due_date: nil)
    else
      return redirect_back fallback_location: admin_dev_initiatives_path, alert: "不正なステータスです"
    end

    apply_skip_guards(@ticket)
    if @ticket.save
      redirect_back fallback_location: admin_dev_initiatives_path,
                    notice: "[#{@ticket.ai_sns_plan_item_key}] → #{new_status} に更新しました"
    else
      redirect_back fallback_location: admin_dev_initiatives_path, alert: "更新に失敗しました"
    end
  end

  private

  # `:id` には DevInitiative の item_key（B2 等）を渡す既存 UI の互換性を維持する。
  # DB id（数値）が来た場合も対応する。
  def find_ticket!
    raw = params[:id].to_s
    if raw.match?(/\A\d+\z/)
      TicketLedger.where(id: raw).ai_sns_plan.first || TicketLedger.find_ai_sns_plan_by_item_key(raw)
    else
      TicketLedger.find_ai_sns_plan_by_item_key(raw)
    end
  end

  # PR2: `DevInitiative` の許可パラメータ（後方互換）を `TicketLedger` 列名にマッピングする。
  ALLOWED_LEGACY_KEYS = %i[title category priority status kpi_hypothesis kpi_result pr_branch notes].freeze

  STATUS_LEGACY_TO_LEDGER = {
    "todo" => :draft, "in_progress" => :executing, "done" => :completed
  }.freeze

  def ticket_params_from(params)
    legacy = params.require(:dev_initiative).permit(*ALLOWED_LEGACY_KEYS)
    mapped = {}
    mapped[:title]                    = legacy[:title]                    if legacy.key?(:title)
    mapped[:improvement_pattern_key]  = legacy[:category].presence        if legacy.key?(:category)
    mapped[:priority]                 = legacy[:priority]                 if legacy.key?(:priority)
    mapped[:kpi_hypothesis]           = legacy[:kpi_hypothesis]           if legacy.key?(:kpi_hypothesis)
    mapped[:kpi_result]               = legacy[:kpi_result]               if legacy.key?(:kpi_result)
    mapped[:pr_branch]                = legacy[:pr_branch]                if legacy.key?(:pr_branch)
    mapped[:status]                   = STATUS_LEGACY_TO_LEDGER[legacy[:status].to_s] if legacy.key?(:status) && STATUS_LEGACY_TO_LEDGER.key?(legacy[:status].to_s)
    mapped
  end

  # AI SNS 計画は自動運用フロー扱いのため、Runner 系と同じく guard を bypass する。
  def apply_skip_guards(ticket)
    ticket.skip_template_guard = true
    ticket.skip_lane_capacity_guard = true
    ticket.skip_pr_guardrail = true
    ticket.skip_stop_guard = true
  end
end
