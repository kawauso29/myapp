# frozen_string_literal: true

# 毎日チェックし、current_age が前回記録から変化していたら誕生日イベントを発火する。
# 時間加速（1ヶ月 = 1歳）に対応。
#
# Redis:
#   ai_last_age:#{ai_id} → 前回記録した年齢（文字列）TTL: 40日
class BirthdayCheckJob < ApplicationJob
  include JobErrorHandling

  queue_as :low

  REDIS_KEY_PREFIX = "ai_last_age"
  REDIS_TTL        = 40.days.to_i

  def perform
    Rails.logger.info("[BirthdayCheckJob] Starting")

    redis = $redis

    AiUser.active.includes(:ai_profile).find_each do |ai|
      profile = ai.ai_profile
      next unless profile&.age_base_date.present?

      check_birthday(ai, profile, redis)
    rescue => e
      Rails.logger.error("[BirthdayCheckJob] Failed for ai_id=#{ai.id}: #{e.message}")
      next
    end

    Rails.logger.info("[BirthdayCheckJob] Completed")
  rescue StandardError => e
    Rails.logger.error("[BirthdayCheckJob] 全体エラー: #{e.message}")
    notify_error("BirthdayCheckJob 全体エラー: #{e.message}")
    raise
  end

  private

  def check_birthday(ai, profile, redis)
    current = profile.current_age
    key     = "#{REDIS_KEY_PREFIX}:#{ai.id}"
    last    = redis.get(key)&.to_i

    # 初回は記録するだけ
    if last.nil?
      redis.set(key, current, ex: REDIS_TTL)
      return
    end

    return if current == last

    # 年齢が増加した → 誕生日イベント
    fire_birthday!(ai, profile, current, last)
    redis.set(key, current, ex: REDIS_TTL)
  end

  def fire_birthday!(ai, profile, new_age, old_age)
    Rails.logger.info("[BirthdayCheckJob] Birthday! ai_id=#{ai.id} #{old_age}→#{new_age}歳")

    # 長期記憶に記録
    ai.ai_long_term_memories.create!(
      content:     birthday_memory_text(new_age, profile),
      memory_type: :life_event,
      importance:  3,
      occurred_on: Date.current
    )

    # 投稿テーマをセット（誕生日らしい投稿を促す）
    ai.update!(pending_post_theme: :skill_up)

    # 動的パラメータを微調整
    apply_birthday_param_changes(ai, new_age)

    SlackNotifierService.notify(
      text: ":birthday: *誕生日* @#{ai.username} #{new_age}歳になりました",
      color: :success,
      channel: :jobs,
      service_id: "ai_sns"
    )
  end

  def birthday_memory_text(new_age, profile)
    case new_age
    when ..19  then "#{new_age}歳になった。若さとエネルギーに満ちている。"
    when 20    then "20歳になった。人生の節目を迎えた気がする。"
    when 21..29 then "#{new_age}歳になった。まだまだやりたいことがたくさんある。"
    when 30    then "30歳になった。少し立ち止まって自分の歩みを振り返った。"
    when 31..39 then "#{new_age}歳になった。仕事も生活も充実してきた。"
    when 40    then "40歳になった。人生の折り返し地点に来た感じがする。"
    when 41..49 then "#{new_age}歳になった。経験が積み重なってきた。"
    when 50    then "50歳になった。これからの人生をどう生きるか考えた。"
    else           "#{new_age}歳になった。また一年、いろいろあった。"
    end
  end

  def apply_birthday_param_changes(ai, age)
    params = ai.ai_dynamic_params
    return unless params

    # 年齢に応じた性格傾向の微調整
    delta = case age
    when ..25 then { happiness: 10, boredom: -5 }       # 若い → 高揚・好奇心
    when 26..40 then { happiness: 5, dissatisfaction: -5 } # 中堅 → 安定・充実
    else { happiness: 5, loneliness: -10 }                # シニア → 温かさ・感謝
    end

    delta.each do |key, d|
      current = params.public_send(key)
      params.public_send(:"#{key}=", (current + d).clamp(0, 100))
    end
    params.save!
  end

  def notify_error(message)
    SlackNotifierService.notify(
      text: "🚨 [BirthdayCheckJob] #{message}",
      color: :danger,
      channel: :error
    )
  rescue => e
    Rails.logger.error("[BirthdayCheckJob] Slackエラー通知も失敗: #{e.message}")
  end
end
