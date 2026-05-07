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

      context "かつ active な StopCondition（target_type: フラグ名）がある場合" do
        before do
          allow(Rails.application.config.x).to receive(:ledger_v2_flags)
            .and_return({ auto_merge: true })
          LedgerV2::StopCondition.create!(
            target_type: "auto_merge", reason: "逆戻り", severity: "high", created_by: "admin"
          )
        end

        it "false を返す（逆戻り条件）" do
          expect(described_class.enabled?(:auto_merge)).to be false
        end
      end

      context "かつ active な StopCondition（target_type: all）がある場合" do
        before do
          allow(Rails.application.config.x).to receive(:ledger_v2_flags)
            .and_return({ auto_merge: true })
          LedgerV2::StopCondition.create!(
            target_type: "all", reason: "全停止", severity: "critical", created_by: "admin"
          )
        end

        it "false を返す（逆戻り条件 — all は全フラグを止める）" do
          expect(described_class.enabled?(:auto_merge)).to be false
        end
      end

      context "かつ inactive な StopCondition（active: false）がある場合" do
        before do
          allow(Rails.application.config.x).to receive(:ledger_v2_flags)
            .and_return({ auto_merge: true })
          LedgerV2::StopCondition.create!(
            target_type: "auto_merge", reason: "解除済み", severity: "low",
            created_by: "admin", active: false
          )
        end

        it "true を返す（inactive な StopCondition は無視）" do
          expect(described_class.enabled?(:auto_merge)).to be true
        end
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

    it "Ticket 23 で monthly_runner は有効化済み（dry_run: true で Layer C 観察中）" do
      expect(described_class.all[:monthly_runner]).to be(true)
    end

    it "Phase G-5（2026-05-07）で auto_merge は有効化済み" do
      expect(described_class.all[:auto_merge]).to be(true)
    end

    it "quarterly_runner / annual_runner / auto_pr はまだ false" do
      still_disabled = %i[quarterly_runner annual_runner auto_pr]
      still_disabled.each do |flag|
        expect(described_class.all[flag]).to be(false),
          "#{flag} はまだ有効化されていないはず"
      end
    end

    it "v2 MVP 運用フラグ（daily / weekly / health_snapshot 等）は有効化済み" do
      operational_flags = %i[daily_runner weekly_runner health_snapshot ticket_creation artifact_generation]
      operational_flags.each do |flag|
        expect(described_class.all[flag]).to be(true),
          "#{flag} は Ticket 1〜18 完了後に有効化されているべき"
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
