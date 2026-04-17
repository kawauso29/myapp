class TicketLedger < ApplicationRecord
  # Phase 30c / 補強3: すべての起票は発生元の会議（またはシステム自動化会議）に紐付く必要がある。
  belongs_to :source_meeting, class_name: "MeetingLedger"

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2
  }, prefix: true

  enum :source_meeting_type, {
    long_term: 0,
    annual: 1,
    quarterly: 2,
    monthly: 3,
    weekly: 4,
    incident: 5
  }, prefix: true

  # Phase 36 / §13: 28日運営レーン
  enum :operating_lane, {
    immediate: 0,
    weekly_improvement: 1,
    monthly_ops: 2,
    quarterly_review_lane: 3
  }, prefix: true

  # §17 / Phase 35: 起票カテゴリ 11 種（+ 既存の運用由来 3 種を後方互換として残す）
  enum :ticket_type, {
    # 旧来（後方互換）
    operations: "operations",
    ops: "ops",
    quarterly_review: "quarterly_review",
    annual_plan: "annual_plan",
    service_pivot: "service_pivot",
    # §17 の 11 種
    initiative: "initiative",             # 1. 施策起票
    investigation: "investigation",       # 2. 調査起票
    audit: "audit",                       # 3. 監査起票
    hr: "hr",                             # 4. 人事起票
    customer_notice: "customer_notice",   # 5. 顧客案内起票
    tech_record: "tech_record",           # 6. 技術記録起票
    org_change: "org_change",             # 7. 組織起票
    exec_plan: "exec_plan",               # 8. 経営起票
    service_launch: "service_launch",     # 9. 新規サービス起票
    service_shutdown: "service_shutdown", # 10. サービス縮小 / 廃止起票
    service_merge: "service_merge",       # 11. サービス統合起票
    improvement: "improvement"            # 10 + effectiveness ループ（§33.3 補強10）
  }, prefix: true

  enum :status, {
    draft: 0,
    approved: 1,
    planned: 2,
    executing: 3,
    waiting_review: 4,
    completed: 5,
    cancelled: 6,
    overdue: 7
  }, prefix: true

  enum :due_cycle, {
    daily: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    annual: 4,
    long_term: 5
  }, prefix: true

  enum :escalation_to, {
    monthly: 0,
    quarterly: 1,
    annual: 2,
    long_term: 3
  }, prefix: true

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: true

  # 補強13: 外部依存 SLA 超過時の自動措置
  enum :sla_breach_action, {
    auto_escalate: 0,
    auto_reject: 1,
    audit_open: 2
  }, prefix: true

  # §32-5 / §31: リスクレベル（GitHub フロー差分制御に使用）
  enum :risk_level, {
    low: 0,
    medium: 1,
    high: 2
  }, prefix: true

  validates :ticket_type, :title, :scope_level, :status, :priority, presence: true
  validates :effectiveness_score,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
            allow_nil: true
  validates :effectiveness_sample_size,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  # scope_level: :service で起票する場合は service_id を必須にする。
  # service 起票には必ず対応サービスが紐付くべきであり、NULL のまま通すと
  # LaneCapacityGuard / Stops::EntryGuard 等の service 単位の集計・検査が漏れる。
  validates :service_id, presence: true, if: :scope_level_service?

  # 補強1: 同一イベントの二重書き込みを DB レベルで防ぐ。
  # 値は任意（既存呼び出しを壊さない）だが、設定時は一意である必要がある。
  validates :idempotency_key, uniqueness: true, allow_nil: true
  # Phase 35 / 補強9: Copilot 標準入力テンプレート ID は "tmpl-<ticket_type>-<id>" 形式で
  # 一意。後から辿り直せるよう ticket 側に保存する（`CopilotInputTemplate#generate` で自動セット）。
  validates :template_id, uniqueness: true, allow_nil: true,
            format: { with: /\Atmpl-[a-z0-9_]+-\d+\z/, message: "must match tmpl-<ticket_type>-<id>" },
            length: { maximum: 128 }
  validate :linked_kpis_not_empty
  validate :sla_breached_at_requires_deadline

  # Phase 33 / 補強7 / §18: active な StopLedger が存在する scope への新規起票をブロックする。
  # 既存テストの互換のためデフォルトは OFF。production では
  # `config/initializers/ticket_stop_guard.rb` で有効化する。
  class_attribute :enforce_stop_guard, instance_accessor: false, default: false

  # stop_guard を自動的に bypass する ticket_type のホワイトリスト。
  # Phase 33 / §18 の趣旨は「通常業務の新規起票を止める」ことであり、以下は停止中でも
  # 記録する必要があるため常に許可する:
  # - investigation / audit: 停止原因の調査 / 監査証跡
  # - quarterly_review / annual_plan: retrospective サマリーの自動生成
  # - service_shutdown: 停止に伴うサービス終了の記録
  STOP_GUARD_BYPASS_TICKET_TYPES = %w[investigation audit quarterly_review annual_plan service_shutdown].freeze

  # Phase 36 / §13: LaneCapacityGuard を起票直前に評価して警告ログを出す。
  # デフォルト OFF。production で ON にして WIP 超過の可視化を得る。
  class_attribute :warn_lane_capacity, instance_accessor: false, default: false

  # Phase 36 / §13: 警告ログで十分な件数集まった後に enforce モードに切替可能。
  # true の場合、WIP 上限を超える TicketLedger.create は `errors.add` + `throw(:abort)` で
  # 作成をキャンセルする（`skip_lane_capacity_guard = true` で例外的に bypass 可能）。
  # デフォルト OFF。plan.md §進め方: "警告ログで十分な件数集まってから"。
  class_attribute :enforce_lane_capacity, instance_accessor: false, default: false

  # Phase 37 / §20: high リスク / investigation / tech_record 起票時に
  # ADR / Runbook が存在するかを check して警告ログを出す。
  class_attribute :warn_pr_guardrail, instance_accessor: false, default: false

  # Phase 37 / §20: 警告ログで十分な件数集まった後に enforce モードに切替可能。
  # true の場合、ADR / Runbook 不足の high リスク ticket 作成を `errors.add` + `throw(:abort)`
  # でキャンセルする（`skip_pr_guardrail = true` で例外的に bypass 可能）。
  # デフォルト OFF。
  class_attribute :enforce_pr_guardrail, instance_accessor: false, default: false

  # Runner や呼び出し側で「このレコードだけは例外的に guard をスキップしたい」場合に
  # `ticket.skip_stop_guard = true` を指定できる。
  attr_accessor :skip_stop_guard, :skip_lane_capacity_guard, :skip_pr_guardrail

  before_create :assert_no_active_stop!, if: :stop_guard_applies?
  before_create :assert_lane_capacity!, if: :enforce_lane_capacity_applies?
  before_create :assert_pr_guardrail!, if: :enforce_pr_guardrail_applies?
  after_create :warn_if_lane_over_capacity, if: :warn_lane_capacity_applies?
  after_create :warn_if_pr_guardrail_missing, if: :warn_pr_guardrail_applies?

  scope :overdue_candidates, -> { where(status: :waiting_review).where("due_date < ?", Date.current) }
  scope :sla_breached, -> { where.not(sla_breached_at: nil) }
  scope :sla_approaching, ->(within: 1.day) {
    where(sla_breached_at: nil)
      .where.not(sla_deadline: nil)
      .where(sla_deadline: Time.current..(Time.current + within))
  }

  before_save :set_resolved_at, if: :will_save_change_to_status?
  before_save :mark_sla_breach, if: :sla_deadline?

  # 補強10: improvement 起票前に類似 pattern の過去 effectiveness_score 平均を返す。
  # サンプルサイズ不足（< 3）や該当なしは nil を返し、呼び出し側で扱いを決める。
  def self.effectiveness_for_pattern(pattern_key, min_sample: 3)
    return nil if pattern_key.blank?

    improvement_tickets = ticket_type_improvement
                            .where(improvement_pattern_key: pattern_key)
                            .where.not(effectiveness_score: nil)
    return nil if improvement_tickets.size < min_sample

    improvement_tickets.average(:effectiveness_score)&.to_f
  end

  def sla_breached?
    sla_breached_at.present?
  end

  private

  def set_resolved_at
    return unless status_approved? || status_cancelled?

    self.resolved_at = Time.current
  end

  def linked_kpis_not_empty
    return unless linked_kpis.blank?

    errors.add(:linked_kpis, "can't be blank")
  end

  def sla_breached_at_requires_deadline
    return if sla_breached_at.blank?
    return if sla_deadline.present?

    errors.add(:sla_breached_at, "requires sla_deadline to be set")
  end

  def mark_sla_breach
    return if sla_breached_at.present?
    return if sla_deadline.blank? || sla_deadline >= Time.current

    self.sla_breached_at = Time.current
  end

  def stop_guard_applies?
    return false if skip_stop_guard
    return false unless self.class.enforce_stop_guard
    return false if STOP_GUARD_BYPASS_TICKET_TYPES.include?(ticket_type.to_s)

    scope_level.present?
  end

  def assert_no_active_stop!
    Stops::EntryGuard.assert!(scope_level: scope_level, service_id: service_id)
  rescue Stops::EntryGuard::Blocked => e
    errors.add(:base, e.message)
    # Rails の before_create コールバックチェーンを中断して create をキャンセルする。
    # ActiveRecord::Rollback を使うと transaction 全体がロールバックされてしまうため
    # `throw(:abort)` が Rails 標準のキャンセル方法。
    throw(:abort)
  end

  def warn_lane_capacity_applies?
    self.class.warn_lane_capacity && operating_lane.present?
  end

  def enforce_lane_capacity_applies?
    return false if skip_lane_capacity_guard
    self.class.enforce_lane_capacity && operating_lane.present?
  end

  def assert_lane_capacity!
    return if Ledgers::LaneCapacityGuard.allowed?(
      operating_lane: operating_lane,
      scope_level: scope_level,
      service_id: service_id
    )

    errors.add(:base, "lane capacity exceeded for #{operating_lane} (scope=#{scope_level}, service=#{service_id})")
    throw(:abort)
  rescue StandardError => e
    # guard 評価そのものが失敗した場合は警告のみで create を通す（安全側）。
    Rails.logger.warn("[LaneCapacityGuard][enforce] check failed for new ticket: #{e.message}")
  end

  def enforce_pr_guardrail_applies?
    return false if skip_pr_guardrail
    self.class.enforce_pr_guardrail &&
      (risk_level.to_s == "high" || %w[investigation tech_record].include?(ticket_type.to_s))
  end

  def assert_pr_guardrail!
    result = Knowledge::PrGuardrail.check(ticket: self)
    return if result.passed?

    errors.add(:base, "pr_guardrail missing artifacts: #{result.missing_artifacts.join(',')}")
    throw(:abort)
  rescue StandardError => e
    Rails.logger.warn("[PrGuardrail][enforce] check failed for new ticket: #{e.message}")
  end

  def warn_if_lane_over_capacity
    return if Ledgers::LaneCapacityGuard.allowed?(
      operating_lane: operating_lane,
      scope_level: scope_level,
      service_id: service_id
    )

    usage = Ledgers::LaneCapacityGuard.current_usage(
      operating_lane: operating_lane,
      scope_level: scope_level,
      service_id: service_id
    )
    Rails.logger.warn(
      "[LaneCapacityGuard] over cap: ticket=##{id} lane=#{operating_lane} scope=#{scope_level} service=#{service_id} usage=#{usage}"
    )
  rescue StandardError => e
    Rails.logger.warn("[LaneCapacityGuard] check failed for ticket=##{id}: #{e.message}")
  end

  def warn_pr_guardrail_applies?
    self.class.warn_pr_guardrail &&
      (risk_level.to_s == "high" || %w[investigation tech_record].include?(ticket_type.to_s))
  end

  def warn_if_pr_guardrail_missing
    result = Knowledge::PrGuardrail.check(ticket: self)
    return if result.passed?

    Rails.logger.warn(
      "[PrGuardrail] missing artifacts for ticket=##{id} type=#{ticket_type} risk=#{risk_level} missing=#{result.missing_artifacts.join(',')}"
    )
  rescue StandardError => e
    Rails.logger.warn("[PrGuardrail] check failed for ticket=##{id}: #{e.message}")
  end
end
