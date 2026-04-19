require "rails_helper"

RSpec.describe PicroCheckJob, type: :job do
  let(:scraper_success) do
    PicroScraperService::Result.new(
      success: true,
      messages: [
        { message_id: "msg_1", sender_name: "田中", title: "練習について", preview: "明日の練習は…", received_at: Time.current }
      ],
      error: nil
    )
  end

  let(:scraper_failure) do
    PicroScraperService::Result.new(success: false, messages: [], error: "ログイン失敗")
  end

  before do
    allow(SlackNotifierService).to receive(:notify)
  end

  describe "#perform" do
    context "スクレイピング失敗時" do
      before { allow_any_instance_of(PicroScraperService).to receive(:call).and_return(scraper_failure) }

      it "Slackエラー通知を送信する" do
        described_class.new.perform

        expect(SlackNotifierService).to have_received(:notify).with(
          hash_including(text: match(/スクレイピング失敗/), color: :danger, channel: :error)
        )
      end

      it "PicroMessageを作成しない" do
        expect { described_class.new.perform }.not_to change(PicroMessage, :count)
      end
    end

    context "新着メッセージがある場合" do
      let(:line_response) { double(code: "200", body: "{}") }

      before do
        allow_any_instance_of(PicroScraperService).to receive(:call).and_return(scraper_success)
        allow_any_instance_of(LineNotifierService).to receive(:notify_new_messages)
      end

      it "PicroMessageを保存する" do
        expect { described_class.new.perform }.to change(PicroMessage, :count).by(1)
      end

      it "LINE通知を送信する" do
        described_class.new.perform
        expect_any_instance_of(LineNotifierService).to have_received(:notify_new_messages)
      end

      it "Slack成功通知を送信する" do
        described_class.new.perform
        expect(SlackNotifierService).to have_received(:notify).with(
          hash_including(text: match(/LINE通知送信済み/), channel: :jobs)
        )
      end
    end

    context "新着なし（既に保存済み）の場合" do
      before do
        allow_any_instance_of(PicroScraperService).to receive(:call).and_return(scraper_success)
        PicroMessage.create!(message_id: "msg_1", title: "既存", notified: true)
      end

      it "LINE通知を送信しない" do
        expect_any_instance_of(LineNotifierService).not_to receive(:notify_new_messages)
        described_class.new.perform
      end
    end

    context "LINE通知が失敗した場合" do
      before do
        allow_any_instance_of(PicroScraperService).to receive(:call).and_return(scraper_success)
        allow_any_instance_of(LineNotifierService).to receive(:notify_new_messages)
          .and_raise("LINE broadcast失敗: code=429 body=rate limit")
      end

      it "Slackエラー通知を送信する" do
        described_class.new.perform

        expect(SlackNotifierService).to have_received(:notify).with(
          hash_including(text: match(/LINE通知失敗/), color: :danger, channel: :error)
        )
      end

      it "notifiedフラグをtrueにしない" do
        described_class.new.perform
        expect(PicroMessage.where(message_id: "msg_1", notified: false).count).to eq(1)
      end
    end
  end
end
