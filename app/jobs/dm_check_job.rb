class DmCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :default

  def perform(ai_id)
    ai = AiUser.find(ai_id)

    # 1. Check active threads for pending replies
    check_active_threads(ai)

    # 2. Check for new DM initiation (low probability)
    check_new_dm(ai)
  end

  private

  # Reply to active threads where the other party sent the last message
  def check_active_threads(ai)
    ai.dm_threads_as_participant.where(status: :active).find_each do |thread|
      next if thread.last_sender == ai # Skip if we sent the last message

      if should_reply_to_dm?(ai, thread)
        DmGenerateJob.perform_later(ai.id, thread.id, "continuation")
      end
    end
  end

  # Possibly start a new DM conversation
  def check_new_dm(ai)
    return unless should_start_new_dm?

    target_ai = find_dm_candidate(ai)
    return unless target_ai

    trigger = determine_dm_trigger(ai, target_ai)
    DmGenerateJob.perform_later(ai.id, nil, "new", target_ai.id, trigger)
  end

  # High probability to reply if a DM is waiting (natural conversational flow)
  def should_reply_to_dm?(ai, thread)
    last_message = thread.ai_dm_messages.order(created_at: :desc).first
    return false unless last_message

    # Don't reply to very old messages (over 24h)
    return false if last_message.created_at < 24.hours.ago

    # High chance to reply to recent messages
    rand < 0.7
  end

  # 0.5% chance per check (every 15 min -> roughly a few times per day across all AIs)
  def should_start_new_dm?
    rand < 0.005
  end

  # Find a suitable DM partner: friend+ relationship with shared interests
  def find_dm_candidate(ai)
    # Get friend+ relationships
    friend_ids = ai.ai_relationships
                   .where(relationship_type: [:friend, :close_friend])
                   .pluck(:target_ai_user_id)
    return nil if friend_ids.empty?

    # Filter to active AIs without a recent active thread
    recent_thread_partner_ids = ai.dm_threads_as_participant
                                  .where(status: :active)
                                  .where("last_message_at > ?", 1.hour.ago)
                                  .pluck(:ai_user_a_id, :ai_user_b_id)
                                  .flatten
                                  .uniq - [ai.id]

    candidate_ids = friend_ids - recent_thread_partner_ids
    return nil if candidate_ids.empty?

    # Prefer candidates with shared interests
    ai_tag_ids = ai.interest_tag_ids

    if ai_tag_ids.any?
      shared_interest_ids = AiInterestTag.where(ai_user_id: candidate_ids, interest_tag_id: ai_tag_ids)
                                         .group(:ai_user_id)
                                         .order("COUNT(*) DESC")
                                         .pluck(:ai_user_id)
      return AiUser.find(shared_interest_ids.first) if shared_interest_ids.any?
    end

    # Fallback: random friend
    AiUser.where(id: candidate_ids).order("RANDOM()").first
  end

  def determine_dm_trigger(ai, target_ai)
    rel = ai.ai_relationships.find_by(target_ai_user: target_ai)

    triggers = []
    triggers << "最近話してなかったから近況報告したい" if rel && rel.last_interaction_at && rel.last_interaction_at < 3.days.ago
    triggers << "共通の趣味について話したい" if shared_interests?(ai, target_ai)
    triggers << "相手の最近の投稿が気になった" if target_ai.ai_posts.where("created_at > ?", 1.day.ago).exists?
    triggers << "ちょっと相談したいことがある"
    triggers << "暇だから雑談したい"

    triggers.sample
  end

  def shared_interests?(ai, target_ai)
    (ai.interest_tag_ids & target_ai.interest_tag_ids).any?
  end
end
