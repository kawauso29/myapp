class ComplianceRule < ApplicationRecord
  # §16 成果物出力前に適用する DB レベルの法務/規程チェック台帳（補強14）。
  enum :law_domain, {
    pii: 0,
    pr_law: 1,
    pharma: 2,
    financial: 3,
    copyright: 4,
    brand: 5,
    internal: 6
  }, prefix: true

  enum :scope_level, {
    company: 0,
    portfolio: 1,
    service: 2
  }, prefix: true

  enum :severity, {
    block: 0,
    warn: 1,
    audit: 2
  }, prefix: true

  enum :owner_role, {
    audit: 0,
    legal: 1,
    exec_audit: 2
  }, prefix: true

  validates :name, :law_domain, :scope_level, :severity, :owner_role, presence: true
  validates :pattern, presence: true
  validates :name, uniqueness: { scope: [ :law_domain, :scope_level, :service_id_pattern ] }

  scope :enforced, -> { where.not(enforced_at: nil).where("enforced_at <= ?", Time.current) }
  scope :applicable_to, ->(scope_level:, service_id: nil) {
    base = enforced.where(scope_level: scope_level)
    next base if service_id.blank?

    base.where("service_id_pattern IS NULL OR service_id_pattern = ? OR ? LIKE REPLACE(service_id_pattern, '*', '%')",
               service_id, service_id)
  }

  # 与えられたテキストに違反する enforced ルールを返す。pattern は Ruby 正規表現として評価する。
  # 不正な正規表現はスキップし、警告扱いにする（運用ログへはサービス層で記録）。
  def self.violations_for(text, scope_level:, service_id: nil)
    return [] if text.blank?

    applicable_to(scope_level: scope_level, service_id: service_id).select do |rule|
      regex = rule.compiled_pattern
      regex.present? && regex.match?(text)
    end
  end

  def compiled_pattern
    Regexp.new(pattern)
  rescue RegexpError
    nil
  end

  def blocking?
    severity_block?
  end
end
