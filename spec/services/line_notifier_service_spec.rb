require "rails_helper"

# line-bot-api 2.7.0 は V2 API に移行し、Line::Bot::Client を削除している。
# LineNotifierService は旧 Client API を使っており本番では旧バージョンで動作するが、
# テスト環境では定数が存在しないためスタブを定義する。
unless defined?(Line::Bot::Client)
  module Line; module Bot; class Client; end; end; end
end

RSpec.describe LineNotifierService do
  let(:messages) do
    [{ title: "練習のお知らせ", preview: "明日の練習は中止です", sender_name: "コーチ" }]
  end

  let(:credentials_base) { { channel_secret: "secret", channel_token: "token" } }
  let(:mock_client) { double("Line::Bot::Client") }
  let(:success_response) { double(code: "200", body: "{}") }

  before do
    allow(Line::Bot::Client).to receive(:new).and_return(mock_client)
  end

  describe "#notify_new_messages" do
    context "friend_idsが設定されている場合" do
      let(:friend_ids) { %w[U001 U002 U003] }

      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(friend_ids: friend_ids, user_id: "U_owner"))
      end

      it "multicastで送信する" do
        expect(mock_client).to receive(:multicast).with(friend_ids, anything).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "user_idのみ設定されている場合" do
      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: "U_owner", friend_ids: nil))
      end

      it "push_messageで送信する" do
        expect(mock_client).to receive(:push_message).with("U_owner", anything).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "どちらも未設定の場合" do
      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: nil, friend_ids: nil))
      end

      it "broadcastで送信する" do
        expect(mock_client).to receive(:broadcast).with(anything).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "LINE APIがエラーを返した場合" do
      let(:error_response) { double(code: "429", body: '{"message":"rate limit"}') }

      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: nil, friend_ids: nil))
        allow(mock_client).to receive(:broadcast).and_return(error_response)
      end

      it "例外をraiseする" do
        expect { described_class.new.notify_new_messages(messages) }
          .to raise_error(RuntimeError, /broadcast失敗/)
      end
    end

    context "messagesが空の場合" do
      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base)
      end

      it "何も送信しない" do
        expect(mock_client).not_to receive(:broadcast)
        expect(mock_client).not_to receive(:multicast)
        expect(mock_client).not_to receive(:push_message)
        described_class.new.notify_new_messages([])
      end
    end
  end
end
