module GithubMapping
  # §32-5: high / medium / low リスクごとの GitHub フロー差分を定義する。
  # §30.6 / §31 のルールに基づき、リスクレベルに応じた必須チェック項目を返す。
  class RiskBasedFlow
    FLOWS = {
      "low" => {
        required_approvals: 0,
        auto_merge_eligible: true,
        audit_review_required: false,
        copilot_autonomous: true,
        deploy_gate: :ci_only,
        labels: %w[risk:low],
        description: "CI通過で自動マージ可能。Copilot 単独実行可。"
      },
      "medium" => {
        required_approvals: 1,
        auto_merge_eligible: true,
        audit_review_required: false,
        copilot_autonomous: true,
        deploy_gate: :ci_and_review,
        labels: %w[risk:medium review-required],
        description: "1名以上のレビュー approve + CI通過で自動マージ。"
      },
      "high" => {
        required_approvals: 2,
        auto_merge_eligible: false,
        audit_review_required: true,
        copilot_autonomous: false,
        deploy_gate: :ci_review_and_audit,
        labels: %w[risk:high audit-required manual-merge],
        description: "監査部レビュー + 2名以上 approve + 手動マージ。Copilot 単独不可。"
      }
    }.freeze

    def self.for(risk_level)
      level = risk_level.to_s
      FLOWS[level] || FLOWS["low"]
    end

    def self.labels_for(risk_level)
      flow = self.for(risk_level)
      flow[:labels]
    end

    def self.auto_merge_eligible?(risk_level)
      flow = self.for(risk_level)
      flow[:auto_merge_eligible]
    end

    def self.copilot_autonomous?(risk_level)
      flow = self.for(risk_level)
      flow[:copilot_autonomous]
    end

    # ticket のリスクレベルに応じた必須チェック項目リストを返す
    def self.required_checks(ticket)
      risk = ticket.risk_level || "low"
      flow = self.for(risk)
      checks = [ :ci_pass ]

      checks << :reviewer_approve if flow[:required_approvals].positive?
      checks << :audit_review if flow[:audit_review_required]
      checks << :manual_merge unless flow[:auto_merge_eligible]
      checks << :customer_success_review if customer_facing?(ticket)

      checks
    end

    def self.customer_facing?(ticket)
      ticket.scope_level == "service" &&
        Array(ticket.linked_artifacts).any? { |a| a.to_s.include?("customer") }
    end
  end
end
