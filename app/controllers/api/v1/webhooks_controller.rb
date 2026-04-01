module Api
  module V1
    class WebhooksController < BaseController
      skip_before_action :authenticate_user!

      PRICE_TO_PLAN = {
        ENV["STRIPE_LIGHT_PRICE_ID"]   => "light",
        ENV["STRIPE_PREMIUM_PRICE_ID"] => "premium"
      }.freeze

      # POST /api/v1/webhooks/stripe
      def stripe
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

        begin
          event = Stripe::Webhook.construct_event(
            payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
          )
        rescue JSON::ParserError
          return head :bad_request
        rescue Stripe::SignatureVerificationError
          return head :bad_request
        end

        case event.type
        when "checkout.session.completed"
          handle_checkout_completed(event.data.object)
        when "customer.subscription.updated"
          handle_subscription_updated(event.data.object)
        when "customer.subscription.deleted"
          handle_subscription_deleted(event.data.object)
        end

        head :ok
      end

      private

      def handle_checkout_completed(session)
        user = User.find_by(id: session.metadata["user_id"])
        return unless user

        subscription = Stripe::Subscription.retrieve(session.subscription)
        price_id = subscription.items.data.first.price.id
        plan = PRICE_TO_PLAN[price_id] || "free"

        user.update!(
          stripe_customer_id: session.customer,
          stripe_subscription_id: session.subscription,
          plan: plan,
          plan_expires_at: Time.at(subscription.current_period_end)
        )
      end

      def handle_subscription_updated(subscription)
        user = User.find_by(stripe_customer_id: subscription.customer)
        return unless user

        price_id = subscription.items.data.first.price.id
        plan = PRICE_TO_PLAN[price_id] || "free"

        user.update!(
          plan: plan,
          plan_expires_at: Time.at(subscription.current_period_end)
        )
      end

      def handle_subscription_deleted(subscription)
        user = User.find_by(stripe_customer_id: subscription.customer)
        return unless user

        user.update!(
          plan: :free,
          stripe_subscription_id: nil,
          plan_expires_at: nil
        )
      end
    end
  end
end
