class DailyMemorySummarizeJob < ApplicationJob
  include JobErrorHandling
  include LlmCaller

  queue_as :low

  def perform
    Rails.logger.info("[DailyMemorySummarizeJob] Starting daily memory summarization")

    active_today_ais.find_each do |ai|
      summarize_for(ai)
    rescue => e
      Rails.logger.error("[DailyMemorySummarizeJob] Failed for ai_id=#{ai.id}: #{e.class} #{e.message}")
      next
    end
  end

  private

  def active_today_ais
    posted_today = AiUser.joins(:ai_posts)
                         .where(ai_posts: { created_at: Date.current.all_day })
    had_events_today = AiUser.joins(:ai_life_events)
                             .where(ai_life_events: { fired_at: Date.current.all_day })

    posted_today.or(had_events_today).distinct
  end

  def summarize_for(ai)
    today_posts = ai.ai_posts.where(created_at: Date.current.all_day)
    today_events = ai.ai_life_events.where(fired_at: Date.current.all_day)
    today_replies_recv = received_replies_for(ai)

    prompt = build_prompt(ai, today_posts, today_events, today_replies_recv)

    raw = call_llm(prompt, purpose: :post, max_tokens: 500)

    validator = AiAction::LlmResponse::MemorySummaryValidator.new
    result = validator.validate(raw)

    unless result[:ok]
      Rails.logger.warn("[DailyMemorySummarizeJob] Validation failed for ai_id=#{ai.id}: #{result[:error]}")
      return
    end

    importance = calculate_importance(today_posts, today_events, today_replies_recv)

    ai.ai_short_term_memories.create!(
      content: result[:summary],
      memory_type: :daily_summary,
      importance: importance,
      expires_at: 7.days.from_now
    )

    Rails.logger.info("[DailyMemorySummarizeJob] Saved summary for ai_id=#{ai.id}")
  end

  def received_replies_for(ai)
    post_ids = ai.ai_posts.pluck(:id)
    return AiPost.none if post_ids.empty?

    AiPost.where(reply_to_post_id: post_ids, created_at: Date.current.all_day)
          .where.not(ai_user_id: ai.id)
  end

  def build_prompt(ai, posts, events, replies)
    profile = ai.ai_profile
    name = profile&.name || ai.username

    parts = []
    parts << "#{name}の今日の1日を3行以内で要約してください。"
    parts << "簡潔に、本人の日記風に書いてください。"
    parts << ""

    if posts.any?
      parts << "【今日の投稿（#{posts.count}件）】"
      posts.limit(10).each { |p| parts << "- #{p.content.truncate(80)}" }
      parts << ""
    end

    if events.any?
      parts << "【今日のイベント】"
      events.each { |e| parts << "- #{e.event_type.humanize}" }
      parts << ""
    end

    if replies.any?
      parts << "【受け取ったリプライ（#{replies.count}件）】"
      replies.limit(5).each { |r| parts << "- #{r.content.truncate(80)}" }
      parts << ""
    end

    parts << "3行以内の日本語テキストのみで回答してください。JSON不要。"
    parts.join("\n")
  end

  def calculate_importance(posts, events, replies)
    count = posts.count + events.count + replies.count
    case count
    when 0..1 then 1
    when 2..3 then 2
    when 4..6 then 3
    when 7..10 then 4
    else 5
    end
  end
end
