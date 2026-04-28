require "rails_helper"

RSpec.describe LedgerV2::Flags do
  describe ".enabled?" do
    context "フラグが true のとき" do
      before do
        allow(Rails.application.config.x).to receive(:ledger_v2_flags)
          .and_return({ daily_runner: true })
      end

      it "true を返す" do
        expect(described_class.enabled?(:daily_runner)).to be true
      end
    end

    context "フラグが false のとき" do
      before do
        allow(Rails.application.config.x).to receive(:ledger_v2_flags)
          .and_return({ daily_runner: false })
      end

      it "false を返す" do
        expect(described_class.enabled?(:daily_runner)).to be false
      end
    end

    context "存在しないフラグのとき" do
      it "false を返す（保守的デフォルト）" do
        expect(described_class.enabled?(:unknown_flag_xyz)).to be false
      end
    end

    it "String でも Symbol と同じ結果を返す" do
      result_sym = described_class.enabled?(:daily_runner)
      result_str = described_class.enabled?("daily_runner")
      expect(result_sym).to eq(result_str)
    end
  end

  describe ".all" do
    it "Hash を返す" do
      expect(described_class.all).to be_a(Hash)
    end

    it "ALL_FLAGS に定義された全フラグを含む" do
      described_class::ALL_FLAGS.each do |flag|
        expect(described_class.all).to have_key(flag)
      end
    end

    it "デフォルト設定では全フラグが false になっている（保守的初期値）" do
      described_class::ALL_FLAGS.each do |flag|
        expect(described_class.all[flag]).to be(false),
          "#{flag} のデフォルト値は false であるべき"
      end
    end
  end

  describe "ALL_FLAGS" do
    it "Symbol の配列である" do
      expect(described_class::ALL_FLAGS).to all(be_a(Symbol))
    end

    it "重複がない" do
      expect(described_class::ALL_FLAGS.uniq).to eq(described_class::ALL_FLAGS)
    end
  end
end
