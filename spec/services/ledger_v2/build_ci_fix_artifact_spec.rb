require "rails_helper"

RSpec.describe LedgerV2::BuildCiFixArtifact, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "WeeklyRunner", trigger_type: :schedule) }

  def call_service(dry_run: false)
    described_class.call(run: run, dry_run: dry_run)
  end

  def create_ci_failure_ticket(suffix: "2026-01-01")
    LedgerV2::Ticket.create!(
      canonical_key:  "ledger_v2:ci_success_rate:below_minimum:daily:#{suffix}",
      title:          "CI 成功率が閾値を下回っています",
      status:         :open,
      severity:       :high,
      metric_name:    "ci_success_rate",
      review_status:  :not_required,
      human_decision: :none
    )
  end

  # auto_pr フラグが無効なケース
  context "auto_pr フラグが無効な場合" do
    before do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_pr).and_return(false)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:artifact_generation).and_return(true)
    end

    it "0 を返す" do
      expect(call_service).to eq(0)
    end

    it "Artifact を作成しない" do
      create_ci_failure_ticket
      expect { call_service }.not_to change(LedgerV2::Artifact, :count)
    end
  end

  # artifact_generation フラグが無効なケース
  context "artifact_generation フラグが無効な場合" do
    before do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_pr).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:artifact_generation).and_return(false)
    end

    it "0 を返す" do
      expect(call_service).to eq(0)
    end

    it "Artifact を作成しない" do
      create_ci_failure_ticket
      expect { call_service }.not_to change(LedgerV2::Artifact, :count)
    end
  end

  # 両フラグが有効なケース
  context "auto_pr および artifact_generation フラグが有効な場合" do
    before do
      allow(LedgerV2::Flags).to receive(:enabled?).with(:auto_pr).and_return(true)
      allow(LedgerV2::Flags).to receive(:enabled?).with(:artifact_generation).and_return(true)
    end

    context "CI 失敗 Ticket がない場合" do
      it "0 を返す" do
        expect(call_service).to eq(0)
      end

      it "Artifact を作成しない" do
        expect { call_service }.not_to change(LedgerV2::Artifact, :count)
      end
    end

    context "CI 失敗 Ticket が 1 件ある場合" do
      let!(:ci_ticket) { create_ci_failure_ticket }

      it "1 を返す" do
        expect(call_service).to eq(1)
      end

      it "Artifact が 1 件作成される" do
        expect { call_service }.to change(LedgerV2::Artifact, :count).by(1)
      end

      it "作成された Artifact の artifact_type が ci_fix_suggestion" do
        call_service
        expect(LedgerV2::Artifact.last.artifact_type).to eq("ci_fix_suggestion")
      end

      it "作成された Artifact の review_status が draft" do
        call_service
        expect(LedgerV2::Artifact.last.review_status).to eq("draft")
      end

      it "作成された Artifact の related_ticket が CI 失敗 Ticket" do
        call_service
        expect(LedgerV2::Artifact.last.related_ticket).to eq(ci_ticket)
      end

      it "artifact_created Event が 1 件作成される" do
        expect { call_service }.to change {
          LedgerV2::Event.where(event_type: "artifact_created").count
        }.by(1)
      end

      it "Artifact 本文にヘッダーが含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("CI 修正案（draft）")
      end

      it "Artifact 本文に関連 Ticket 情報が含まれる" do
        call_service
        body = LedgerV2::Artifact.last.body
        expect(body).to include("関連 Ticket: ##{ci_ticket.id}")
      end

      it "Artifact 本文に障害分類セクションが含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("障害分類")
      end

      it "Artifact 本文に修正案セクションが含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("修正案")
      end

      it "Artifact 本文に免責事項が含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("人間が承認してから行ってください")
      end

      context "同じ Ticket に対して 2 回呼ばれた場合（冪等性）" do
        before { call_service }

        it "Artifact を追加作成しない" do
          expect { call_service }.not_to change(LedgerV2::Artifact, :count)
        end

        it "返り値が 0" do
          expect(call_service).to eq(0)
        end
      end

      context "dry_run: true の場合" do
        it "作成されるはずの件数 1 を返す" do
          expect(call_service(dry_run: true)).to eq(1)
        end

        it "Artifact を作成しない" do
          expect { call_service(dry_run: true) }.not_to change(LedgerV2::Artifact, :count)
        end
      end
    end

    context "CI 失敗 Ticket が複数ある場合" do
      let!(:ticket_a) { create_ci_failure_ticket(suffix: "2026-01-01") }
      let!(:ticket_b) { create_ci_failure_ticket(suffix: "2026-01-02") }

      it "Artifact が Ticket の件数分作成される" do
        expect { call_service }.to change(LedgerV2::Artifact, :count).by(2)
      end

      it "返り値が Ticket の件数と一致する" do
        expect(call_service).to eq(2)
      end
    end

    context "metric_name が ci_success_rate でない Ticket は対象外" do
      before do
        LedgerV2::Ticket.create!(
          canonical_key:  "ledger_v2:error_count:exceeded_threshold:daily:2026-01-01",
          title:          "エラー件数が閾値を超えています",
          status:         :open,
          severity:       :high,
          metric_name:    "error_count",
          review_status:  :not_required,
          human_decision: :none
        )
      end

      it "0 を返す" do
        expect(call_service).to eq(0)
      end
    end

    context "SolidQueue に lint 系の失敗がある場合" do
      before do
        allow(SolidQueue::FailedExecution).to receive_message_chain(:order, :limit, :to_a).and_return([
          instance_double(SolidQueue::FailedExecution, error: "RuboCop offense detected at app/foo.rb")
        ])
      end

      let!(:ci_ticket) { create_ci_failure_ticket }

      it "修正案に rubocop コマンドが含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("rubocop --autocorrect")
      end
    end

    context "SolidQueue に test 系の失敗がある場合" do
      before do
        allow(SolidQueue::FailedExecution).to receive_message_chain(:order, :limit, :to_a).and_return([
          instance_double(SolidQueue::FailedExecution, error: "RSpec::Expectations::ExpectationNotMetError")
        ])
      end

      let!(:ci_ticket) { create_ci_failure_ticket }

      it "修正案に rspec コマンドが含まれる" do
        call_service
        expect(LedgerV2::Artifact.last.body).to include("rspec")
      end
    end
  end
end
