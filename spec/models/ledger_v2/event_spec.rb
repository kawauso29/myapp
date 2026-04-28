require "rails_helper"

RSpec.describe LedgerV2::Event, type: :model do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }

  describe "create" do
    it "valid なレコードを保存できる" do
      event = LedgerV2::Event.new(
        run: run,
        event_type: "metric_snapshot_created",
        occurred_at: Time.current
      )
      expect(event.save).to be true
    end

    it "デフォルトの severity は info になる" do
      event = LedgerV2::Event.create!(
        run: run,
        event_type: "metric_snapshot_created",
        occurred_at: Time.current
      )
      expect(event.severity_info?).to be true
    end

    it "すべての severity 値を保存できる" do
      LedgerV2::Event.severities.each_key do |s|
        event = LedgerV2::Event.create!(
          run: run,
          event_type: "runner_skipped",
          severity: s,
          occurred_at: Time.current
        )
        expect(event.severity).to eq(s)
      end
    end
  end

  describe "バリデーション" do
    it "run_id が nil だと invalid になる" do
      event = LedgerV2::Event.new(event_type: "anomaly_detected", occurred_at: Time.current)
      expect(event).not_to be_valid
      expect(event.errors[:run]).not_to be_empty
    end

    it "event_type が空だと invalid になる" do
      event = LedgerV2::Event.new(run: run, occurred_at: Time.current)
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).not_to be_empty
    end

    it "occurred_at が nil だと invalid になる" do
      event = LedgerV2::Event.new(run: run, event_type: "anomaly_detected")
      expect(event).not_to be_valid
      expect(event.errors[:occurred_at]).not_to be_empty
    end
  end

  describe "belongs_to :run" do
    it "run を参照できる" do
      event = LedgerV2::Event.create!(
        run: run,
        event_type: "ticket_opened",
        occurred_at: Time.current
      )
      expect(event.run).to eq(run)
    end
  end
end
