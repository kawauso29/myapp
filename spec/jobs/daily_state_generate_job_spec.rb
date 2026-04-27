require "rails_helper"

RSpec.describe DailyStateGenerateJob, type: :job do
  describe "#perform" do
    let!(:active_ai)   { create(:ai_user, is_active: true) }
    let!(:inactive_ai) { create(:ai_user, is_active: false) }

    before do
      allow(Daily::DailyStateGenerator).to receive(:generate)
    end

    it "calls DailyStateGenerator for each active AI" do
      described_class.new.perform
      expect(Daily::DailyStateGenerator).to have_received(:generate).with(active_ai)
    end

    it "does not call DailyStateGenerator for inactive AIs" do
      described_class.new.perform
      expect(Daily::DailyStateGenerator).not_to have_received(:generate).with(inactive_ai)
    end

    context "when a daily state already exists for today" do
      before do
        create(:ai_daily_state, ai_user: active_ai, date: Date.current)
      end

      it "skips generation" do
        described_class.new.perform
        expect(Daily::DailyStateGenerator).not_to have_received(:generate).with(active_ai)
      end
    end

    context "when generation raises an error for one AI" do
      let!(:other_ai) { create(:ai_user, is_active: true) }

      before do
        allow(Daily::DailyStateGenerator)
          .to receive(:generate).with(active_ai).and_raise(StandardError, "boom")
        allow(Daily::DailyStateGenerator)
          .to receive(:generate).with(other_ai)
      end

      it "continues processing remaining AIs" do
        expect { described_class.new.perform }.not_to raise_error
        expect(Daily::DailyStateGenerator).to have_received(:generate).with(other_ai)
      end
    end
  end

  describe "#apply_seasonal_post_theme" do
    let(:job) { described_class.new }

    context "when today has a cherry_blossom event" do
      let(:state) { instance_double("AiDailyState", today_events: %w[cherry_blossom]) }
      let(:ai)    { create(:ai_user, is_active: true) }

      it "sets pending_post_theme to new_hobby" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to eq("new_hobby")
      end
    end

    context "when today has a new_season event" do
      let(:state) { instance_double("AiDailyState", today_events: %w[new_season]) }
      let(:ai)    { create(:ai_user, is_active: true) }

      it "sets pending_post_theme to skill_up" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to eq("skill_up")
      end
    end

    context "when today has a valentine event and AI is coupled" do
      let(:state) { instance_double("AiDailyState", today_events: %w[valentine]) }
      let(:ai)    { create(:ai_user, is_active: true) }

      before { ai.ai_profile.update!(relationship_status: :in_relationship) }

      it "sets pending_post_theme to new_relationship" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to eq("new_relationship")
      end
    end

    context "when today has a valentine event and AI is single" do
      let(:state) { instance_double("AiDailyState", today_events: %w[valentine]) }
      let(:ai)    { create(:ai_user, is_active: true) }

      before { ai.ai_profile.update!(relationship_status: :single) }

      it "does not set pending_post_theme" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to be_nil
      end
    end

    context "when AI already has a pending_post_theme" do
      let(:state) { instance_double("AiDailyState", today_events: %w[cherry_blossom]) }
      let(:ai)    { create(:ai_user, is_active: true, pending_post_theme: :job_change) }

      it "does not override the existing theme" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to eq("job_change")
      end
    end

    context "when today has no events" do
      let(:state) { instance_double("AiDailyState", today_events: []) }
      let(:ai)    { create(:ai_user, is_active: true) }

      it "does not update pending_post_theme" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to be_nil
      end
    end

    context "when today has an event with no theme mapping (e.g. tanabata)" do
      let(:state) { instance_double("AiDailyState", today_events: %w[tanabata]) }
      let(:ai)    { create(:ai_user, is_active: true) }

      it "does not set pending_post_theme" do
        job.send(:apply_seasonal_post_theme, ai, state)
        expect(ai.reload.pending_post_theme).to be_nil
      end
    end
  end
end
