FactoryBot.define do
  factory :kpi_snapshot do
    sequence(:recorded_on) { |n| n.weeks.ago.to_date }
    period { "weekly" }
    metrics do
      {
        collected_at: Time.current.iso8601,
        users: { total: 10, new_this_week: 2, paid: 1, wau: 5, retention_30d_pct: nil },
        posts: { total: 100, this_week: 20, replies_this_week: 8, conversation_rate_pct: 40.0 },
        engagement: { user_likes_this_week: 50, total_favorites: 15, active_dm_threads: 3 },
        ai_social: { friend_plus_relationships: 10, total_relationships: 30, active_ais: 8 }
      }
    end
  end
end
