require "rails_helper"

RSpec.describe LedgerV2::RunExecutor, type: :service do
  # テスト用スタブ Runner — LedgerV2::StubRunner として登録する
  let(:stub_runner_class) do
    Class.new do
      def self.call(run:, dry_run:, **_args)
        LedgerV2::RunExecutor::RunnerResult.new(
          created_ticket_count:      1,
          updated_ticket_count:      0,
          created_artifact_count:    0,
          created_event_count:       2,
          duplicate_prevented_count: 0
        )
      end
    end
  end

  before { stub_const("LedgerV2::StubRunner", stub_runner_class) }

  describe ".call" do
    it "Run が :running → :success に遷移する" do
      run = described_class.call(:stub_runner)

      expect(run).to be_a(LedgerV2::Run)
      expect(run.status_success?).to be true
    end

    it "runner_name を CamelCase で Run に保存する" do
      run = described_class.call(:stub_runner)

      expect(run.runner_name).to eq("StubRunner")
    end

    it "dry_run: true を渡すと Run の dry_run が true になる" do
      run = described_class.call(:stub_runner, dry_run: true)

      expect(run.dry_run).to be true
    end

    it "runner_result のカウンタが Run に反映される" do
      run = described_class.call(:stub_runner)

      expect(run.created_ticket_count).to eq(1)
      expect(run.created_event_count).to  eq(2)
    end

    it "duration_ms が記録される" do
      run = described_class.call(:stub_runner)

      expect(run.duration_ms).to be >= 0
    end

    it "同一 idempotency_key の Run が既にある場合、既存の Run を返す" do
      existing = LedgerV2::Run.create!(
        runner_name:     "StubRunner",
        trigger_type:    :test,
        idempotency_key: "idem-test-key"
      )

      run = described_class.call(:stub_runner, idempotency_key: "idem-test-key")

      expect(run.id).to eq(existing.id)
    end

    it "Runner が例外を出した場合 Run が :failed に更新され再 raise される" do
      failing_runner = Class.new do
        def self.call(run:, dry_run:, **_args)
          raise "runner_failed"
        end
      end
      stub_const("LedgerV2::FailingRunner", failing_runner)

      expect {
        described_class.call(:failing_runner)
      }.to raise_error(RuntimeError, "runner_failed")

      run = LedgerV2::Run.where(runner_name: "FailingRunner").last
      expect(run.status_failed?).to  be true
      expect(run.error_message).to   eq("runner_failed")
      expect(run.error_class).to     eq("RuntimeError")
    end
  end

  describe "CircuitBreaker 統合" do
    it "active な StopCondition があると Run が :blocked になる" do
      LedgerV2::StopCondition.create!(
        target_type: "runner", target_name: "StubRunner",
        reason: "統合テスト用停止", severity: "high", created_by: "admin"
      )

      run = described_class.call(:stub_runner)

      expect(run.status_blocked?).to be true
      expect(run.skipped_reason).to  eq("統合テスト用停止")
    end

    it "target_type: all の StopCondition もブロックする" do
      LedgerV2::StopCondition.create!(
        target_type: "all",
        reason: "全停止中", severity: "critical", created_by: "admin"
      )

      run = described_class.call(:stub_runner)

      expect(run.status_blocked?).to be true
    end
  end

  describe "FeatureFlag 統合" do
    it "monthly_runner はデフォルト false のため skipped になる" do
      run = described_class.call(:monthly_runner, dry_run: true)

      expect(run.status_skipped?).to be true
      expect(run.skipped_reason).to eq("feature_disabled")
    end

    it "monthly_runner フラグが true なら RunExecutor 経由で success になる" do
      allow(LedgerV2::Flags).to receive(:enabled?).and_call_original
      allow(LedgerV2::Flags).to receive(:enabled?).with(:monthly_runner).and_return(true)

      run = described_class.call(:monthly_runner, dry_run: true)

      expect(run.status_success?).to be true
      expect(run.runner_name).to eq("MonthlyRunner")
    end
  end

  describe "RunnerResult" do
    it "カウンタのデフォルトは 0 になる" do
      result = LedgerV2::RunExecutor::RunnerResult.new

      expect(result.created_ticket_count).to      eq(0)
      expect(result.duplicate_prevented_count).to eq(0)
    end
  end
end
