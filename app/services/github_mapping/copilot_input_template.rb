module GithubMapping
  # §32-4: Copilot coding agent に渡す標準入力テンプレート。
  # §30.4 の入力項目を構造化したテンプレートを ticket_ledger から自動生成する。
  # 補強9（Copilot 標準入力テンプレート ID 化）に対応。
  class CopilotInputTemplate
    TEMPLATE_VERSION = "1.0"

    def self.generate(ticket)
      new(ticket).generate
    end

    def initialize(ticket)
      @ticket = ticket
    end

    def generate
      {
        template_version: TEMPLATE_VERSION,
        template_id: template_id,
        context: context_section,
        instructions: instructions_section,
        constraints: constraints_section
      }
    end

    # Issue/PR コメントとして挿入できる Markdown 形式で出力する
    def to_markdown
      tmpl = generate
      <<~MD
        ## Copilot Input Template (v#{TEMPLATE_VERSION})

        ### Context
        | 項目 | 値 |
        |---|---|
        | template_id | #{tmpl[:template_id]} |
        | service_id | #{tmpl[:context][:service_id]} |
        | business_unit_id | #{tmpl[:context][:business_unit_id]} |
        | risk_level | #{tmpl[:context][:risk_level]} |
        | source_ticket_id | #{tmpl[:context][:source_ticket_id]} |

        ### linked_kpis
        #{Array(tmpl[:context][:linked_kpis]).map { |k| "- #{k}" }.join("\n")}

        ### Instructions
        #{tmpl[:instructions][:description]}

        ### Constraints
        #{tmpl[:constraints].map { |c| "- #{c}" }.join("\n")}
      MD
    end

    private

    attr_reader :ticket

    def template_id
      "tmpl-#{ticket.ticket_type}-#{ticket.id}"
    end

    def context_section
      {
        service_id: ticket.service_id,
        business_unit_id: ticket.business_owner,
        linked_kpis: Array(ticket.linked_kpis),
        risk_level: ticket.risk_level || "low",
        source_ticket_id: ticket.id,
        scope_level: ticket.scope_level,
        change_scope: change_scope_description
      }
    end

    def instructions_section
      {
        description: ticket.title,
        spec_reference: spec_reference,
        execution_plan: "ticket_ledger ##{ticket.id} に基づく実装を行う",
        tech_record_update: tech_record_needed?,
        customer_announcement_update: customer_announcement_needed?
      }
    end

    def constraints_section
      constraints = [
        "§31 ルール1: 仕様書がない実装着手は禁止",
        "§31 ルール2: 実行計画がないPR作成は禁止"
      ]

      case ticket.risk_level
      when "high"
        constraints << "§30.6 ルール3: high リスク変更は Copilot 単独で完結させない"
        constraints << "監査部レビュー必須"
      when "medium"
        constraints << "レビュワー1名以上の approve 必須"
      end

      constraints << "§31 ルール6: 監査部は GitHub 上のレビュー/チェック結果で停止提案できる"
      constraints
    end

    def change_scope_description
      "#{ticket.scope_level} / #{ticket.service_id || 'company-wide'}"
    end

    def spec_reference
      "ticket_ledger ##{ticket.id} (#{ticket.ticket_type})"
    end

    def tech_record_needed?
      %w[operations improvement service_shutdown service_pivot].include?(ticket.ticket_type)
    end

    def customer_announcement_needed?
      ticket.scope_level == "service"
    end
  end
end
