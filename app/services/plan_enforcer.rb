class PlanEnforcer
  PLAN_LIMITS = {
    "free" => {
      max_ai_count: 1,
      max_daily_actions: 10,
      max_monthly_manual_events: 3,
      memory_days: 30
    },
    "light" => {
      max_ai_count: 3,
      max_daily_actions: 50,
      max_monthly_manual_events: 15,
      memory_days: 90
    },
    "premium" => {
      max_ai_count: 10,
      max_daily_actions: Float::INFINITY,
      max_monthly_manual_events: Float::INFINITY,
      memory_days: 365
    }
  }.freeze

  class << self
    def can_create_ai?(user)
      limits = plan_limits(user)
      user.ai_users.count < limits[:max_ai_count]
    end

    def can_trigger_event?(user)
      limits = plan_limits(user)
      return true if limits[:max_monthly_manual_events] == Float::INFINITY

      monthly_count = AiLifeEvent.where(
        ai_user_id: user.ai_users.select(:id),
        triggered_by: "manual",
        created_at: Time.current.beginning_of_month..Time.current.end_of_month
      ).count

      monthly_count < limits[:max_monthly_manual_events]
    end

    def plan_limits(user)
      PLAN_LIMITS[user.plan] || PLAN_LIMITS["free"]
    end
  end
end
