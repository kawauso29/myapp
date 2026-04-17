module Org
  # Phase 2 補強 / 穴④: 組織再編ワークフローの最小骨格。
  # `OrgChangeLedger` のモデルだけ存在してワークフロー（propose → approve → activate / rollback）が
  # 接続されていなかったため、4 つの遷移を冪等な API として提供する。
  #
  # 詳細な権限ルール（誰が approve できるか）や HrEvaluation との連動は今後の Phase で拡張する前提。
  # 現状は「台帳の状態遷移を安全に行う」最低限の責務のみ持つ。
  #
  # 使い方:
  #   change = Org::ChangeProposer.propose(
  #     change_type: :role_create,
  #     subject_role: "growth_lead",
  #     scope_level: :service, service_id: "ai_sns",
  #     diff: { add: { role: "growth_lead", reports_to: "service_lead" } },
  #     rationale: "Q2 KPI: WAU 改善のため growth ロールを新設",
  #     source_meeting: meeting,
  #     source_ticket: ticket
  #   )
  #   Org::ChangeProposer.approve(change, by: "ceo", reason: "annual_plan で承認済")
  #   Org::ChangeProposer.activate(change, effective_from: Date.current)
  #   Org::ChangeProposer.rollback(change, reason: "1Q 試行で効果薄")
  class ChangeProposer
    class InvalidTransition < StandardError; end

    class << self
      def propose(change_type:, scope_level:, diff: {},
                  subject_role: nil, service_id: nil, rationale: nil,
                  source_meeting: nil, source_ticket: nil, idempotency_key: nil)
        key = idempotency_key || build_idempotency_key(change_type, subject_role, scope_level, service_id)
        OrgChangeLedger.find_or_create_by!(idempotency_key: key) do |ledger|
          ledger.change_type = change_type
          ledger.scope_level = scope_level
          ledger.service_id = service_id
          ledger.subject_role = subject_role
          ledger.diff = diff || {}
          ledger.rationale = rationale
          ledger.status = :proposed
          ledger.source_meeting = source_meeting
          ledger.source_ticket = source_ticket
        end
      end

      def approve(change, by:, reason: nil)
        unless change.status_proposed?
          raise InvalidTransition, "approve requires status=proposed (got #{change.status})"
        end

        merged_diff = (change.diff || {}).merge(
          "approved_by" => by,
          "approved_at" => Time.current.iso8601,
          "approval_reason" => reason
        )
        change.update!(status: :approved, diff: merged_diff)
        change
      end

      def activate(change, effective_from: Date.current)
        unless change.status_approved?
          raise InvalidTransition, "activate requires status=approved (got #{change.status})"
        end

        change.update!(status: :in_effect, effective_from: effective_from)
        change
      end

      def rollback(change, reason:)
        unless change.status_in_effect? || change.status_approved?
          raise InvalidTransition, "rollback requires status in [approved, in_effect] (got #{change.status})"
        end

        merged_diff = (change.diff || {}).merge(
          "rolled_back_at" => Time.current.iso8601,
          "rollback_reason" => reason
        )
        change.update!(status: :rolled_back, diff: merged_diff)
        change
      end

      private

      def build_idempotency_key(change_type, subject_role, scope_level, service_id)
        "org_change:#{change_type}:#{scope_level}:#{service_id || 'all'}:#{subject_role || 'na'}:#{Date.current.iso8601}"
      end
    end
  end
end
