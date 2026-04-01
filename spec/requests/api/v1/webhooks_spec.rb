require "rails_helper"

RSpec.describe "Stripe Webhooks", type: :request do
  let(:user) { create(:user) }
  let(:stripe_secret) { "whsec_test_secret" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("STRIPE_WEBHOOK_SECRET").and_return(stripe_secret)
    allow(ENV).to receive(:[]).with("STRIPE_LIGHT_PRICE_ID").and_return("price_light_123")
    allow(ENV).to receive(:[]).with("STRIPE_PREMIUM_PRICE_ID").and_return("price_premium_123")
  end

  def post_webhook(payload, signature: "valid_signature")
    allow(Stripe::Webhook).to receive(:construct_event).and_return(
      Stripe::Event.construct_from(JSON.parse(payload.to_json))
    )
    post "/api/v1/webhooks/stripe",
         params: payload.to_json,
         headers: { "Content-Type" => "application/json", "Stripe-Signature" => signature }
  end

  def post_webhook_with_invalid_signature
    allow(Stripe::Webhook).to receive(:construct_event)
      .and_raise(Stripe::SignatureVerificationError.new("invalid", "sig"))
    post "/api/v1/webhooks/stripe",
         params: "{}",
         headers: { "Content-Type" => "application/json", "Stripe-Signature" => "bad_sig" }
  end

  describe "POST /api/v1/webhooks/stripe" do
    context "checkout.session.completed" do
      let(:mock_subscription) do
        Stripe::Subscription.construct_from({
          id: "sub_test_123",
          customer: "cus_test_123",
          current_period_end: 1_800_000_000,
          items: {
            data: [
              { price: { id: "price_light_123" } }
            ]
          }
        })
      end

      let(:payload) do
        {
          type: "checkout.session.completed",
          data: {
            object: {
              customer: "cus_test_123",
              subscription: "sub_test_123",
              metadata: { user_id: user.id.to_s }
            }
          }
        }
      end

      before do
        allow(Stripe::Subscription).to receive(:retrieve).with("sub_test_123").and_return(mock_subscription)
      end

      it "updates user plan and subscription info" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.stripe_customer_id).to eq("cus_test_123")
        expect(user.stripe_subscription_id).to eq("sub_test_123")
        expect(user.plan).to eq("light")
      end
    end

    context "customer.subscription.updated" do
      before do
        user.update!(stripe_customer_id: "cus_test_123")
      end

      let(:payload) do
        {
          type: "customer.subscription.updated",
          data: {
            object: {
              id: "sub_test_123",
              customer: "cus_test_123",
              current_period_end: 1_800_000_000,
              items: {
                data: [{ price: { id: "price_premium_123" } }]
              }
            }
          }
        }
      end

      it "updates user plan" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.plan).to eq("premium")
      end
    end

    context "customer.subscription.deleted" do
      before do
        user.update!(
          stripe_customer_id: "cus_test_123",
          stripe_subscription_id: "sub_test_123",
          plan: :light
        )
      end

      let(:payload) do
        {
          type: "customer.subscription.deleted",
          data: {
            object: {
              id: "sub_test_123",
              customer: "cus_test_123"
            }
          }
        }
      end

      it "resets user plan to free" do
        post_webhook(payload)
        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.plan).to eq("free")
        expect(user.stripe_subscription_id).to be_nil
      end
    end

    context "invalid signature" do
      it "returns 400" do
        post_webhook_with_invalid_signature
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
