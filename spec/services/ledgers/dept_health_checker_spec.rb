require "rails_helper"

RSpec.describe Ledgers::DeptHealthChecker do
  describe ".call" do
    before do
      allow(Ledgers::SlackNotifier).to receive(:notify)
    end

    describe "no_runbook_update rule" do
      it "creates a ticket when no runbook has been created in RUNBOOK_STALE_DAYS days" do
        # Runbook が存在しない場合
        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find_by("linked_kpis->>'rule' = 'no_runbook_update'")
        expect(ticket).to be_present
        expect(ticket.title).to include("No runbook created in")
        expect(result[:detected]).to be >= 1
      end

      it "does not create a ticket when a recent runbook exists" do
        create(:knowledge_ledger, kind: :runbook, status: :accepted, created_at: 1.day.ago)

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'no_runbook_update'").count
        }
      end

      it "does not create a duplicate ticket when one is already open" do
        create(:ticket_ledger,
               ticket_type: :improvement,
               status: :waiting_review,
               linked_kpis: { "rule" => "no_runbook_update" })

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'no_runbook_update'").count
        }
      end
    end

    describe "no_customer_notice rule" do
      it "creates a ticket when no customer_notice has been created recently" do
        # customer_notice が存在しない状態
        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find_by("linked_kpis->>'rule' = 'no_customer_notice'")
        expect(ticket).to be_present
        expect(ticket.title).to include("No customer notice")
        expect(result[:detected]).to be >= 1
      end

      it "does not create a ticket when a recent customer_notice exists" do
        create(:artifact_ledger,
               artifact_type: :customer_notice,
               status: :published,
               created_at: 1.day.ago)

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'no_customer_notice'").count
        }
      end
    end

    describe "stale_artifact rule" do
      it "creates a ticket when published artifacts have not been updated in STALE_ARTIFACT_DAYS days" do
        create(:artifact_ledger,
               artifact_type: :spec,
               status: :published,
               published_at: 100.days.ago,
               updated_at: 100.days.ago,
               created_at: 100.days.ago)

        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find_by("linked_kpis->>'rule' = 'stale_artifact'")
        expect(ticket).to be_present
        expect(ticket.title).to include("stale published artifacts")
        expect(result[:detected]).to be >= 1
      end

      it "does not create a ticket when all published artifacts are fresh" do
        create(:artifact_ledger,
               artifact_type: :spec,
               status: :published,
               published_at: 1.day.ago,
               updated_at: 1.day.ago)

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'stale_artifact'").count
        }
      end
    end

    describe "missing_adr rule" do
      it "creates a ticket when no ADR has been created in RUNBOOK_STALE_DAYS days" do
        # ADR が存在しない場合
        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find_by("linked_kpis->>'rule' = 'missing_adr'")
        expect(ticket).to be_present
        expect(ticket.title).to include("No ADR created")
        expect(result[:detected]).to be >= 1
      end

      it "does not create a ticket when a recent ADR exists" do
        create(:knowledge_ledger, kind: :adr, status: :accepted, created_at: 1.day.ago)

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'missing_adr'").count
        }
      end
    end

    describe "dept_meeting_skip rule" do
      let!(:weekly_definition) do
        create(:meeting_definition, meeting_key: "weekly_dept", meeting_type: :weekly,
               scope_level: :service, service_id: "ai_sns")
      end

      it "creates a ticket when an active service has no weekly meeting in MEETING_SKIP_DAYS days" do
        ServiceLedger.create!(service_id: "ai_sns", scope_level: :service,
                              business_owner: "owner", status: :active)
        # 最後の会議が 20 日前（MEETING_SKIP_DAYS=14 を超えている）
        create(:meeting_ledger,
               meeting_definition: weekly_definition,
               meeting_key: "weekly_dept",
               service_id: "ai_sns",
               held_at: 20.days.ago,
               status: :closed)

        result = described_class.call

        ticket = TicketLedger.ticket_type_improvement.find_by("linked_kpis->>'rule' = 'dept_meeting_skip'")
        expect(ticket).to be_present
        expect(ticket.linked_kpis).to include("rule" => "dept_meeting_skip", "service_id" => "ai_sns")
        expect(result[:detected]).to be >= 1
      end

      it "does not create a ticket when a recent weekly meeting exists" do
        ServiceLedger.create!(service_id: "ai_sns", scope_level: :service,
                              business_owner: "owner", status: :active)
        create(:meeting_ledger,
               meeting_definition: weekly_definition,
               meeting_key: "weekly_dept",
               service_id: "ai_sns",
               held_at: 2.days.ago,
               status: :closed)

        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'dept_meeting_skip'").count
        }
      end

      it "does not create a ticket when no ServiceLedger is active" do
        # active なサービスがなければスキップ
        expect {
          described_class.call
        }.not_to change {
          TicketLedger.ticket_type_improvement
                      .where("linked_kpis->>'rule' = 'dept_meeting_skip'").count
        }
      end
    end

    it "notifies Slack when tickets are created" do
      # no_runbook_update などが検知される状況
      described_class.call

      expect(Ledgers::SlackNotifier).to have_received(:notify)
        .with(hash_including(operation: "dept_health_check"))
    end

    it "does not notify Slack when no issues are detected" do
      # 全ルールが正常（最近の runbook / ADR / customer_notice が存在）
      create(:knowledge_ledger, kind: :runbook, status: :accepted, created_at: 1.day.ago)
      create(:knowledge_ledger, kind: :adr,     status: :accepted, created_at: 1.day.ago)
      create(:artifact_ledger,  artifact_type: :customer_notice, status: :published, created_at: 1.day.ago)
      create(:artifact_ledger,  artifact_type: :spec, status: :published, created_at: 1.day.ago, updated_at: 1.day.ago)
      # ServiceLedger が空（dept_meeting_skip が起動しない）

      result = described_class.call

      expect(result[:detected]).to eq(0)
      expect(Ledgers::SlackNotifier).not_to have_received(:notify)
    end
  end
end
