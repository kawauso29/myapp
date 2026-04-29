require "rails_helper"

RSpec.describe LedgerV2::CollectAiSnsMetrics, type: :service do
  let(:run) { LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule) }
  let(:since_at) { Time.current.beginning_of_day }

  def call_collector(period: :daily, since_at: self.since_at)
    described_class.call(run: run, period: period, since_at: since_at)
  end

  describe ".call" do
    context "AI-SNS データが存在しない場合" do
      it "3 件の MetricSnapshot を返す（posts / dm / reaction）" do
        snapshots = call_collector
        expect(snapshots.size).to eq(3)
      end

      it "MetricSnapshot が 3 件 DB に保存される" do
        expect { call_collector }.to change(LedgerV2::MetricSnapshot, :count).by(3)
      end

      it "metric_name に ai_sns_posts_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("ai_sns_posts_count")
      end

      it "metric_name に ai_sns_dm_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("ai_sns_dm_count")
      end

      it "metric_name に ai_sns_reaction_count が含まれる" do
        snapshots = call_collector
        expect(snapshots.map(&:metric_name)).to include("ai_sns_reaction_count")
      end

      it "値がすべて 0 になる（データなし）" do
        snapshots = call_collector
        expect(snapshots.map(&:value)).to all(eq(0))
      end
    end

    context "AI-SNS データが存在する場合" do
      let(:ai_user) { AiUser.first || create(:ai_user) }

      it "posts_count が AiPost.count と一致する" do
        count = AiPost.where("created_at >= ?", since_at).count
        snapshots = call_collector
        snap = snapshots.find { |s| s.metric_name == "ai_sns_posts_count" }
        expect(snap.value).to eq(count)
      end
    end

    context "readonly の保証" do
      it "AiPost へ書き込みを行わない" do
        expect { call_collector }.not_to change(AiPost, :count)
      end

      it "AiDmThread へ書き込みを行わない" do
        expect { call_collector }.not_to change(AiDmThread, :count)
      end

      it "AiPostLike へ書き込みを行わない" do
        expect { call_collector }.not_to change(AiPostLike, :count)
      end
    end

    context "period: :weekly の場合" do
      it "period が weekly のスナップショットを保存する" do
        snapshots = call_collector(period: :weekly)
        expect(snapshots.map(&:period).uniq).to eq(["weekly"])
      end
    end

    context "冪等性（同じ条件で 2 回呼んだ場合）" do
      it "2 回目は MetricSnapshot を増やさない" do
        call_collector
        run2 = LedgerV2::Run.create!(runner_name: "DailyRunner", trigger_type: :schedule)
        expect {
          described_class.call(run: run2, period: :daily, since_at: since_at)
        }.not_to change(LedgerV2::MetricSnapshot, :count)
      end
    end

    context "MetricSnapshot が METRIC_NAMES 定数と整合している" do
      it "METRIC_NAMES に 3 要素が定義されている" do
        expect(described_class::METRIC_NAMES.size).to eq(3)
      end

      it "METRIC_NAMES が期待する名前を含む" do
        expect(described_class::METRIC_NAMES).to include(
          "ai_sns_posts_count",
          "ai_sns_dm_count",
          "ai_sns_reaction_count"
        )
      end
    end
  end
end
