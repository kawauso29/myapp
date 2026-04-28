require "rails_helper"

RSpec.describe LedgerV2::MetricSnapshot, type: :model do
  # 最小限の有効な属性を返すヘルパー
  def valid_attrs(overrides = {})
    {
      metric_name: "ai_sns_posts_count",
      value:       42.0,
      period:      :daily,
      measured_at: Time.current
    }.merge(overrides)
  end

  describe "create（基本保存）" do
    it "必須カラムが揃っていれば保存できる" do
      snapshot = described_class.new(valid_attrs)
      expect(snapshot.save).to be true
    end

    it "デフォルトの period は hourly になる" do
      snapshot = described_class.create!(valid_attrs.except(:period))
      expect(snapshot.period_hourly?).to be true
    end

    it "value を小数で保存できる" do
      snapshot = described_class.create!(valid_attrs(value: 98.765))
      expect(snapshot.value.to_f).to be_within(0.001).of(98.765)
    end

    it "unit を保存できる" do
      snapshot = described_class.create!(valid_attrs(unit: "count"))
      expect(snapshot.unit).to eq("count")
    end

    it "source_type / source_id を保存できる" do
      snapshot = described_class.create!(valid_attrs(source_type: "AiUser", source_id: "42"))
      expect(snapshot.source_type).to eq("AiUser")
      expect(snapshot.source_id).to eq("42")
    end

    it "payload_json を保存できる" do
      snapshot = described_class.create!(valid_attrs(payload_json: { "note" => "test" }))
      expect(snapshot.payload_json["note"]).to eq("test")
    end
  end

  describe "バリデーション" do
    it "metric_name が空だと無効" do
      snapshot = described_class.new(valid_attrs(metric_name: nil))
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:metric_name]).to be_present
    end

    it "value が空だと無効" do
      snapshot = described_class.new(valid_attrs(value: nil))
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:value]).to be_present
    end

    it "measured_at が空だと無効" do
      snapshot = described_class.new(valid_attrs(measured_at: nil))
      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:measured_at]).to be_present
    end
  end

  describe "enum（period）" do
    it "すべての period 値を保存できる" do
      described_class.periods.each_key do |p|
        snapshot = described_class.create!(valid_attrs(metric_name: "metric:#{p}", period: p))
        expect(snapshot.period).to eq(p)
      end
    end

    it "prefix つき述語メソッドが存在する" do
      snapshot = described_class.create!(valid_attrs)
      expect(snapshot).to respond_to(:period_daily?)
      expect(snapshot).not_to respond_to(:daily?)
    end
  end

  describe "アソシエーション" do
    it "created_by_run を持てる" do
      run = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
      snapshot = described_class.create!(valid_attrs(created_by_run: run))
      expect(snapshot.created_by_run).to eq(run)
    end

    it "created_by_run は optional（nil でも保存できる）" do
      snapshot = described_class.new(valid_attrs)
      expect(snapshot.save).to be true
      expect(snapshot.created_by_run).to be_nil
    end
  end
end
