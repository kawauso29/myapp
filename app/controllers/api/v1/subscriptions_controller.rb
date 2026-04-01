module Api
  module V1
    class SubscriptionsController < BaseController
      PLAN_PRICES = {
        "light"   => ENV["STRIPE_LIGHT_PRICE_ID"],
        "premium" => ENV["STRIPE_PREMIUM_PRICE_ID"]
      }.freeze

      # GET /api/v1/subscriptions
      def index
        user = current_user

        data = {
          plan: user.plan,
          stripe_customer_id: user.stripe_customer_id,
          stripe_subscription_id: user.stripe_subscription_id,
          plan_expires_at: user.plan_expires_at&.iso8601,
          plan_limits: PlanEnforcer.plan_limits(user)
        }

        render_success(data)
      end

      # POST /api/v1/subscriptions/checkout
      def checkout
        plan = params[:plan]

        unless PLAN_PRICES.key?(plan)
          return render_error(code: "invalid_plan", message: "無効なプランです", status: :bad_request)
        end

        customer = find_or_create_stripe_customer
        price_id = PLAN_PRICES[plan]

        session = Stripe::Checkout::Session.create(
          customer: customer.id,
          mode: "subscription",
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/subscription/success?session_id={CHECKOUT_SESSION_ID}",
          cancel_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/subscription/cancel",
          metadata: { user_id: current_user.id }
        )

        render_success({ checkout_url: session.url })
      end

      # POST /api/v1/subscriptions/portal
      def portal
        unless current_user.stripe_customer_id.present?
          return render_error(code: "no_customer", message: "Stripe顧客情報がありません", status: :bad_request)
        end

        session = Stripe::BillingPortal::Session.create(
          customer: current_user.stripe_customer_id,
          return_url: "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/settings"
        )

        render_success({ portal_url: session.url })
      end

      private

      def find_or_create_stripe_customer
        if current_user.stripe_customer_id.present?
          Stripe::Customer.retrieve(current_user.stripe_customer_id)
        else
          customer = Stripe::Customer.create(
            email: current_user.email,
            metadata: { user_id: current_user.id }
          )
          current_user.update!(stripe_customer_id: customer.id)
          customer
        end
      end
    end
  end
end
