require "rails_helper"

RSpec.describe LedgerV2::Run, type: :model do
  describe "create" do
    it "valid なレコードを保存できる" do
      run = LedgerV2::Run.new(runner_name: "DailyRunner", trigger_type: :schedule)
      expect(run.save).to be true
    end

    it "デフォルトの status は pending になる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      expect(run.status_pending?).to be true
    end

    it "デフォルトの dry_run は false になる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      expect(run.dry_run).to be false
    end

    it "dry_run: true を保存できる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :test, dry_run: true)
      expect(run.dry_run).to be true
    end

    it "すべての status 値を保存できる" do
      LedgerV2::Run.statuses.each_key do |s|
        run = LedgerV2::Run.create!(runner_name: "R", trigger_type: :test, status: s)
        expect(run.status).to eq(s)
      end
    end

    it "すべての trigger_type 値を保存できる" do
      LedgerV2::Run.trigger_types.each_key do |t|
        run = LedgerV2::Run.create!(runner_name: "R", trigger_type: t)
        expect(run.trigger_type).to eq(t)
      end
    end
  end

  describe "バリデーション" do
    it "runner_name が空だと invalid になる" do
      run = LedgerV2::Run.new(trigger_type: :schedule)
      expect(run).not_to be_valid
      expect(run.errors[:runner_name]).not_to be_empty
    end

    it "カウンタ系カラムは負の値を受け付けない" do
      run = LedgerV2::Run.new(runner_name: "R", trigger_type: :test, created_ticket_count: -1)
      expect(run).not_to be_valid
    end
  end

  describe "has_many :events" do
    it "events を持てる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      event = run.events.create!(event_type: "runner_skipped", occurred_at: Time.current)
      expect(run.events).to include(event)
    end
  end
end
