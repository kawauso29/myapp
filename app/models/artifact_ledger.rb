class ArtifactLedger < ApplicationRecord
  # Phase 31 / §16: 成果物 6 種類を台帳化する。バージョン管理は `artifact_version` と
  # `supersedes_id`（self-reference）で表現し、古い版は `status: :superseded` で残す。
  belongs_to :supersedes, class_name: "ArtifactLedger", optional: true
  has_many :supersessions, class_name: "ArtifactLedger", foreign_key: :supersedes_id, dependent: :restrict_with_error

  belongs_to :source_meeting, class_name: "MeetingLedger", optional: true
  belongs_to :source_ticket, class_name: "TicketLedger", optional: true

  enum :artifact_type, {
    kpi_definition: 0,
    spec: 1,
    execution_plan: 2,
    audit_judgment: 3,
    customer_notice: 4,
    tech_record: 5
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2,
    cross_service: 3
  }, prefix: true

  enum :status, {
    draft: 0,
    published: 1,
    superseded: 2,
    archived: 3
  }, prefix: true

  validates :artifact_type, :scope_level, :title, :artifact_version, :status, presence: true
  validates :artifact_version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  # DB 側の idx_artifact_ledgers_type_title_version と一致するモデル側検証。
  # 同一 artifact_type + title の中で version は一意。
  validates :artifact_version, uniqueness: { scope: [ :artifact_type, :title ] }
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validate :version_consistency_with_supersedes

  scope :current_versions, -> { where(status: [ :draft, :published ]) }

  private

  # supersedes を指定した場合は artifact_version が元版 + 1、title と artifact_type が同一であることを要求する。
  def version_consistency_with_supersedes
    return if supersedes.blank?

    # 自己参照（supersedes_id == id）は循環チェーンの起点になるため明示的に禁止する。
    if persisted? && supersedes_id == id
      errors.add(:supersedes_id, "must not reference self")
      return
    end

    errors.add(:artifact_type, "must match superseded version") unless supersedes.artifact_type == artifact_type
    errors.add(:title, "must match superseded version") unless supersedes.title == title
    errors.add(:artifact_version, "must be superseded version + 1") unless artifact_version == supersedes.artifact_version + 1
  end
end
