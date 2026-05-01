require "rails_helper"

RSpec.describe LedgerV2::TicketDeduplicator, type: :service do
  def valid_ticket_attrs(overrides = {})
    { canonical_key: "ai_sns:global:post_count:low:2026w18", title: "投稿数が低下" }.merge(overrides)
  end

  describe ".call" do
    context "Level 1: canonical_key 完全一致" do
      it "active な Ticket が存在する場合は duplicate? true を返す" do
        key = "ai_sns:global:post_count:low:2026w18"
        LedgerV2::Ticket.create!(valid_ticket_attrs(canonical_key: key, status: :open))

        result = described_class.call(canonical_key: key)

        expect(result.duplicate?).to be true
        expect(result.duplicate_level).to eq(1)
        expect(result.existing_ticket).to be_a(LedgerV2::Ticket)
        expect(result.reason).to be_present
      end

      it "in_progress 状態でも duplicate を検出する" do
        key = "ai_sns:global:dm_count:low:2026w18"
        LedgerV2::Ticket.create!(valid_ticket_attrs(canonical_key: key, status: :in_progress))

        result = described_class.call(canonical_key: key)

        expect(result.duplicate?).to be true
        expect(result.duplicate_level).to eq(1)
      end

      it "deferred 状態でも duplicate を検出する" do
        key = "ai_sns:global:reply_rate:low:2026w18"
        LedgerV2::Ticket.create!(valid_ticket_attrs(canonical_key: key, status: :deferred))

        result = described_class.call(canonical_key: key)

        expect(result.duplicate?).to be true
      end

      it "resolved 状態なら重複とみなさない（再起票可能）" do
        key = "ai_sns:global:engagement:low:2026w18"
        LedgerV2::Ticket.create!(valid_ticket_attrs(canonical_key: key, status: :resolved))

        result = described_class.call(canonical_key: key)

        expect(result.duplicate?).to be false
        expect(result.existing_ticket).to be_nil
      end

      it "rejected 状態なら重複とみなさない（再起票可能）" do
        key = "ai_sns:global:engagement:low:2026w19"
        LedgerV2::Ticket.create!(valid_ticket_attrs(canonical_key: key, status: :rejected))

        result = described_class.call(canonical_key: key)

        expect(result.duplicate?).to be false
      end

      it "Ticket が存在しない場合は duplicate? false を返す" do
        result = described_class.call(canonical_key: "non:existent:key")

        expect(result.duplicate?).to be false
        expect(result.existing_ticket).to be_nil
        expect(result.reason).to be_nil
        expect(result.duplicate_level).to be_nil
      end
    end

    context "Level 2: source_type + source_id + metric_name + anomaly_type 一致" do
      it "canonical_key が違っても source 属性が全一致する active Ticket があれば duplicate? true" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w17",
          title:         "投稿数低下",
          status:        :open,
          source_type:   "AiUser",
          source_id:     "42",
          metric_name:   "post_count",
          anomaly_type:  "low"
        )

        result = described_class.call(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          source_type:   "AiUser",
          source_id:     "42",
          metric_name:   "post_count",
          anomaly_type:  "low"
        )

        expect(result.duplicate?).to be true
        expect(result.duplicate_level).to eq(2)
        expect(result.reason).to be_present
      end

      it "source 属性が部分的に一致しても duplicate? false を返す" do
        LedgerV2::Ticket.create!(
          canonical_key: "ai_sns:global:post_count:low:2026w17",
          title:         "投稿数低下",
          status:        :open,
          source_type:   "AiUser",
          source_id:     "42",
          metric_name:   "post_count",
          anomaly_type:  "low"
        )

        result = described_class.call(
          canonical_key: "ai_sns:global:post_count:low:2026w18",
          source_type:   "AiUser",
          source_id:     "42",
          metric_name:   "post_count",
          anomaly_type:  "high"  # anomaly_type が違う
        )

        expect(result.duplicate?).to be false
      end

      it "source 引数が nil のときは Level 2 チェックをスキップする" do
        result = described_class.call(
          canonical_key: "ci:main:success_rate:low:2026w18",
          source_type:   nil,
          source_id:     nil,
          metric_name:   "success_rate",
          anomaly_type:  "low"
        )

        expect(result.duplicate?).to be false
      end
    end

    context "Level 3: metric_name + anomaly_type 一致（日付横断・グローバル異常）" do
      it "source_type が nil で同一 metric_name + anomaly_type の active Ticket があれば duplicate? true" do
        LedgerV2::Ticket.create!(
          canonical_key: "ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-05-01",
          title:         "AI-SNS 投稿数低下",
          status:        :open,
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "below_minimum"
        )

        result = described_class.call(
          canonical_key: "ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-05-02",
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "below_minimum"
        )

        expect(result.duplicate?).to be true
        expect(result.duplicate_level).to eq(3)
        expect(result.reason).to be_present
        expect(result.existing_ticket).to be_a(LedgerV2::Ticket)
      end

      it "既存 Ticket が resolved であれば Level 3 で重複とみなさない（再起票可能）" do
        LedgerV2::Ticket.create!(
          canonical_key: "ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-05-01",
          title:         "AI-SNS 投稿数低下",
          status:        :resolved,
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "below_minimum"
        )

        result = described_class.call(
          canonical_key: "ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-05-02",
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "below_minimum"
        )

        expect(result.duplicate?).to be false
      end

      it "source_type が存在する場合は Level 3 をスキップする（Level 2 が担当）" do
        LedgerV2::Ticket.create!(
          canonical_key: "ledger_v2:post_count:low:daily:2026-05-01",
          title:         "投稿数低下",
          status:        :open,
          source_type:   "AiUser",
          source_id:     "42",
          metric_name:   "post_count",
          anomaly_type:  "low"
        )

        result = described_class.call(
          canonical_key: "ledger_v2:post_count:low:daily:2026-05-02",
          source_type:   "AiUser",
          source_id:     "99",  # 異なる source_id
          metric_name:   "post_count",
          anomaly_type:  "low"
        )

        expect(result.duplicate?).to be false
      end

      it "anomaly_type が異なれば Level 3 は発火しない" do
        LedgerV2::Ticket.create!(
          canonical_key: "ledger_v2:ai_sns_posts_count:below_minimum:daily:2026-05-01",
          title:         "投稿数低下",
          status:        :open,
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "below_minimum"
        )

        result = described_class.call(
          canonical_key: "ledger_v2:ai_sns_posts_count:exceeded_threshold:daily:2026-05-02",
          metric_name:   "ai_sns_posts_count",
          anomaly_type:  "exceeded_threshold"
        )

        expect(result.duplicate?).to be false
      end
    end
  end
end
