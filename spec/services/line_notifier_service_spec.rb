require "rails_helper"

RSpec.describe LineNotifierService do
  let(:messages) do
    [{ title: "練習のお知らせ", preview: "明日の練習は中止です", sender_name: "コーチ" }]
  end

  let(:credentials_base) { { channel_secret: "secret", channel_token: "token" } }
  let(:mock_client) { instance_double(Line::Bot::V2::MessagingApi::ApiClient) }
  let(:success_response) { ["{}", 200, {}] }

  before do
    allow(Line::Bot::V2::MessagingApi::ApiClient).to receive(:new).and_return(mock_client)
  end

  describe "#notify_new_messages" do
    context "friend_idsが設定されている場合" do
      let(:friend_ids) { %w[U001 U002 U003] }

      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(friend_ids: friend_ids, user_id: "U_owner"))
      end

      it "multicastで送信する" do
        expect(mock_client).to receive(:multicast_with_http_info).with(
          multicast_request: hash_including(to: friend_ids, messages: anything)
        ).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "user_idのみ設定されている場合" do
      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: "U_owner", friend_ids: nil))
      end

      it "push_messageで送信する" do
        expect(mock_client).to receive(:push_message_with_http_info).with(
          push_message_request: hash_including(to: "U_owner", messages: anything)
        ).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "どちらも未設定の場合" do
      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: nil, friend_ids: nil))
      end

      it "broadcastで送信する" do
        expect(mock_client).to receive(:broadcast_with_http_info).with(
          broadcast_request: hash_including(messages: anything)
        ).and_return(success_response)
        described_class.new.notify_new_messages(messages)
      end
    end

    context "LINE APIがエラーを返した場合" do
      let(:error_response) { double(code: "429", body: '{"message":"rate limit"}') }

      before do
        allow(Rails.application.credentials).to receive(:line!)
          .and_return(credentials_base.merge(user_id: nil, friend_ids: nil))
        allow(mock_client).to receive(:broadcast_with_http_info).and_return([error_response.body, error_response.code.to_i, {}])
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
        expect(mock_client).not_to receive(:broadcast_with_http_info)
        expect(mock_client).not_to receive(:multicast_with_http_info)
        expect(mock_client).not_to receive(:push_message_with_http_info)
        described_class.new.notify_new_messages([])
      end
    end
  end
end
