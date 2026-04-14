namespace :ai_sns do
  desc "Show AI SNS system status"
  task status: :environment do
    puts "=== AI SNS Status ==="
    puts ""

    ai_count = AiUser.count
    puts "AI Users: #{ai_count}"
    puts "  - With profiles: #{AiProfile.count}"
    puts "  - With personalities: #{AiPersonality.count}"
    puts ""

    puts "Posts: #{AiPost.count}"
    puts "  - Today: #{AiPost.where('created_at >= ?', Time.zone.now.beginning_of_day).count}"
    puts ""

    puts "Daily States (today): #{AiDailyState.where('created_at >= ?', Time.zone.now.beginning_of_day).count} / #{ai_count}"
    puts ""

    puts "Relationships: #{AiRelationship.count}"
    puts "Likes: #{AiPostLike.count}"
    puts "User-AI Likes: #{UserAiLike.count}"
    puts ""

    puts "Memories:"
    puts "  - Short-term: #{AiShortTermMemory.count}"
    puts "  - Long-term: #{AiLongTermMemory.count}"
    puts "  - Relationship: #{AiRelationshipMemory.count}"
    puts ""

    puts "Users: #{User.count}"
    puts "Favorites: #{UserFavoriteAi.count}"
    puts ""

    # Sidekiq queue info
    require "sidekiq/api"
    stats = Sidekiq::Stats.new
    puts "Sidekiq:"
    puts "  - Processed: #{stats.processed}"
    puts "  - Failed: #{stats.failed}"
    puts "  - Enqueued: #{stats.enqueued}"
    puts "  - Retry set: #{stats.retry_size}"
    puts ""
    puts "=== End ==="
  end

  desc "Manually trigger daily state generation for all AI users"
  task generate_daily_states: :environment do
    puts "Triggering DailyStateGenerateJob..."
    DailyStateGenerateJob.perform_later
    puts "Job enqueued."
  end

  desc "Manually trigger AI action check"
  task run_action_check: :environment do
    puts "Triggering AiActionCheckJob..."
    AiActionCheckJob.perform_later
    puts "Job enqueued."
  end

  desc "Run AI seed script"
  task seed_ais: :environment do
    puts "Running AI seed..."
    load Rails.root.join("db/seeds.rb")
    puts "Seed complete."
  end
end
