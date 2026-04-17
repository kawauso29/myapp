require "rails_helper"

RSpec.describe Stops::ConditionEvaluator do
  describe "#call" do
    it "creates a kpi_breach stop when a KPI grade=critical exists" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :critical,
             current_value: { "value" => 10 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_kpi_breach
      expect(stop.service_id).to eq("ai_sns")
      expect(stop.evidence).to include("kpi_key" => "wau")
    end

    it "is idempotent within the same day" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :critical,
             current_value: { "value" => 10 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      described_class.call(scope_level: :service, service_id: "ai_sns")
      second = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(second.created).to be_empty
      expect(StopLedger.where(trigger_type: StopLedger.trigger_types[:kpi_breach]).count).to eq(1)
    end

    it "does not create a stop for healthy KPIs" do
      create(:kpi_ledger,
             service_id: "ai_sns",
             kpi_key: "wau",
             status: :active,
             grade: :healthy,
             current_value: { "value" => 120 },
             thresholds: { "healthy" => 100, "warning" => 50 })

      result = described_class.call(scope_level: :service, service_id: "ai_sns")
      expect(result.created).to be_empty
    end

    it "records a manual_escalation stop when OperatorOverrideLedger has an active halt_service" do
      OperatorOverrideLedger.create!(
        action: :halt_service,
        scope_level: :service,
        service_id: "ai_sns",
        operator: "op1",
        reason: "manual kill switch",
        started_at: 1.hour.ago
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_manual_escalation
      expect(stop.service_id).to eq("ai_sns")
    end

    it "is idempotent for manual_escalation within the same day" do
      OperatorOverrideLedger.create!(
        action: :halt_service,
        scope_level: :service,
        service_id: "ai_sns",
        operator: "op1",
        reason: "manual kill switch",
        started_at: 1.hour.ago
      )

      described_class.call(scope_level: :service, service_id: "ai_sns")
      second = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(second.created).to be_empty
      expect(StopLedger.where(trigger_type: StopLedger.trigger_types[:manual_escalation]).count).to eq(1)
    end

    it "creates a cost_runaway stop when monthly cost exceeds the threshold" do
      ENV["COST_RUNAWAY_MONTHLY_JPY"] = "1000"
      CostLedger.create!(
        subject_type: :job,
        subject_id: "job1",
        scope_level: :service,
        service_id: "ai_sns",
        amount_jpy: 5000,
        source: :llm_api,
        incurred_at: Time.current
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.size).to eq(1)
      stop = result.created.first
      expect(stop).to be_trigger_type_cost_runaway
      expect(stop.evidence["monthly_total_jpy"].to_f).to be >= 5000.0
    ensure
      ENV.delete("COST_RUNAWAY_MONTHLY_JPY")
    end

    it "does not create cost_runaway when monthly cost is under threshold" do
      ENV["COST_RUNAWAY_MONTHLY_JPY"] = "10000"
      CostLedger.create!(
        subject_type: :job,
        subject_id: "job1",
        scope_level: :service,
        service_id: "ai_sns",
        amount_jpy: 100,
        source: :llm_api,
        incurred_at: Time.current
      )

      result = described_class.call(scope_level: :service, service_id: "ai_sns")

      expect(result.created.select { |s| s.trigger_type == "cost_runaway" }).to be_empty
    ensure
      ENV.delete("COST_RUNAWAY_MONTHLY_JPY")
    end

    context "error_spike" do
      it "creates an error_spike stop when failed executions exceed the threshold" do
        ENV["ERROR_SPIKE_THRESHOLD"] = "2"
        # SolidQueue テーブルが存在しない場合はスキップ相当なので存在チェックをモックする
        allow_any_instance_of(described_class).to receive(:error_spike_table_exists?).and_return(true)
        allow(SolidQueue::FailedExecution).to receive(:where).and_return(
          double("scope", count: 3)
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        stop = result.created.find { |s| s.trigger_type == "error_spike" }
        expect(stop).to be_present
        expect(stop).to be_trigger_type_error_spike
        expect(stop.evidence["failed_count"]).to eq(3)
      ensure
        ENV.delete("ERROR_SPIKE_THRESHOLD")
      end

      it "does not create error_spike when count is below threshold" do
        ENV["ERROR_SPIKE_THRESHOLD"] = "10"
        allow_any_instance_of(described_class).to receive(:error_spike_table_exists?).and_return(true)
        allow(SolidQueue::FailedExecution).to receive(:where).and_return(
          double("scope", count: 2)
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        expect(result.created.select { |s| s.trigger_type == "error_spike" }).to be_empty
      ensure
        ENV.delete("ERROR_SPIKE_THRESHOLD")
      end

      it "is idempotent within the same 10-minute slot" do
        ENV["ERROR_SPIKE_THRESHOLD"] = "2"
        allow_any_instance_of(described_class).to receive(:error_spike_table_exists?).and_return(true)
        allow(SolidQueue::FailedExecution).to receive(:where).and_return(
          double("scope", count: 5)
        )

        described_class.call(scope_level: :service, service_id: "ai_sns")
        second = described_class.call(scope_level: :service, service_id: "ai_sns")

        expect(second.created.select { |s| s.trigger_type == "error_spike" }).to be_empty
      ensure
        ENV.delete("ERROR_SPIKE_THRESHOLD")
      end
    end

    context "security_incident" do
      it "creates a security_incident stop when a security_risk audit decision exists within 24h" do
        audit_ticket = create(:ticket_ledger, service_id: "ai_sns")
        AuditDecisionLedger.create!(
          target_ticket: audit_ticket,
          decision: :reject,
          reason_code: "security_risk",
          audit_role: "audit_board",
          scope_level: :service,
          service_id: "ai_sns",
          decided_at: 1.hour.ago
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        stop = result.created.find { |s| s.trigger_type == "security_incident" }
        expect(stop).to be_present
        expect(stop).to be_trigger_type_security_incident
      end

      it "does not create security_incident when the audit decision is older than 24h" do
        audit_ticket = create(:ticket_ledger, service_id: "ai_sns")
        AuditDecisionLedger.create!(
          target_ticket: audit_ticket,
          decision: :reject,
          reason_code: "security_risk",
          audit_role: "audit_board",
          scope_level: :service,
          service_id: "ai_sns",
          decided_at: 25.hours.ago
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        expect(result.created.select { |s| s.trigger_type == "security_incident" }).to be_empty
      end
    end

    context "compliance_violation" do
      it "creates a compliance_violation stop when an enforced block-severity ComplianceRule exists" do
        ComplianceRule.create!(
          name: "PII block rule",
          law_domain: :pii,
          scope_level: :service,
          service_id_pattern: "ai_sns",
          severity: :block,
          owner_role: :audit,
          pattern: "\\bSSN\\b",
          enforced_at: 1.day.ago
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        stop = result.created.find { |s| s.trigger_type == "compliance_violation" }
        expect(stop).to be_present
        expect(stop).to be_trigger_type_compliance_violation
      end

      it "does not create compliance_violation when the rule is not yet enforced" do
        ComplianceRule.create!(
          name: "Future PII block rule",
          law_domain: :pii,
          scope_level: :service,
          service_id_pattern: "ai_sns",
          severity: :block,
          owner_role: :audit,
          pattern: "\\bSSN\\b",
          enforced_at: 1.day.from_now
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        expect(result.created.select { |s| s.trigger_type == "compliance_violation" }).to be_empty
      end

      it "does not create compliance_violation when the rule is warn-severity" do
        ComplianceRule.create!(
          name: "PII warn rule",
          law_domain: :pii,
          scope_level: :service,
          service_id_pattern: "ai_sns",
          severity: :warn,
          owner_role: :audit,
          pattern: "\\bSSN\\b",
          enforced_at: 1.day.ago
        )

        result = described_class.call(scope_level: :service, service_id: "ai_sns")

        expect(result.created.select { |s| s.trigger_type == "compliance_violation" }).to be_empty
      end
    end
  end
end
