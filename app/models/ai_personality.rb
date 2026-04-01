class AiPersonality < ApplicationRecord
  belongs_to :ai_user

  LEVEL_ENUM = {
    very_low:  1,
    low:       2,
    normal:    3,
    high:      4,
    very_high: 5
  }.freeze

  LEVEL_LABELS = {
    very_low:  "非常に低い",
    low:       "低い",
    normal:    "普通",
    high:      "高い",
    very_high: "非常に高い"
  }.freeze

  PURPOSE_ENUM = {
    information_seeker: 0,
    approval_seeker:    1,
    connector:          2,
    self_recorder:      3,
    entertainer:        4,
    venter:             5,
    observer:           6,
    influencer:         7
  }.freeze

  enum :sociability,        LEVEL_ENUM, prefix: true
  enum :post_frequency,     LEVEL_ENUM, prefix: true
  enum :active_time_peak,   LEVEL_ENUM, prefix: true
  enum :need_for_approval,  LEVEL_ENUM, prefix: true
  enum :emotional_range,    LEVEL_ENUM, prefix: true
  enum :risk_tolerance,     LEVEL_ENUM, prefix: true
  enum :self_expression,    LEVEL_ENUM, prefix: true
  enum :drinking_frequency, LEVEL_ENUM, prefix: true
  enum :self_esteem,        LEVEL_ENUM, prefix: true
  enum :empathy,            LEVEL_ENUM, prefix: true
  enum :jealousy,           LEVEL_ENUM, prefix: true
  enum :curiosity,          LEVEL_ENUM, prefix: true
  enum :primary_purpose,    PURPOSE_ENUM, prefix: true
  enum :secondary_purpose,  PURPOSE_ENUM, prefix: true

  enum :follow_philosophy, {
    casual:     1,
    selective:  2,
    reciprocal: 3,
    cautious:   4,
    collector:  5
  }, prefix: true

  validates :sociability, :post_frequency, :active_time_peak,
            :need_for_approval, :emotional_range, :risk_tolerance,
            :self_expression, :drinking_frequency, :self_esteem,
            :empathy, :jealousy, :curiosity,
            presence: true
  validates :primary_purpose, :follow_philosophy, presence: true

  def to_prompt_hash
    {
      sociability:       LEVEL_LABELS[sociability.to_sym],
      post_frequency:    LEVEL_LABELS[post_frequency.to_sym],
      active_time_peak:  active_time_label,
      need_for_approval: LEVEL_LABELS[need_for_approval.to_sym],
      emotional_range:   LEVEL_LABELS[emotional_range.to_sym],
      risk_tolerance:    LEVEL_LABELS[risk_tolerance.to_sym],
      self_expression:   LEVEL_LABELS[self_expression.to_sym],
      self_esteem:       LEVEL_LABELS[self_esteem.to_sym],
      empathy:           LEVEL_LABELS[empathy.to_sym],
      primary_purpose:   purpose_label(primary_purpose)
    }
  end

  private

  def active_time_label
    {
      very_low:  "朝型（6〜9時がピーク）",
      low:       "やや朝型（7〜12時）",
      normal:    "標準（12〜21時に分散）",
      high:      "やや夜型（20〜24時）",
      very_high: "深夜型（23〜3時がピーク）"
    }[active_time_peak.to_sym]
  end

  def purpose_label(purpose)
    {
      information_seeker: "情報収集・学びたい",
      approval_seeker:    "いいねがほしい・バズりたい",
      connector:          "友達・仲間を作りたい",
      self_recorder:      "日記・記録として使いたい",
      entertainer:        "面白いことを発信したい",
      venter:             "本音を吐き出したい",
      observer:           "基本は見るだけ",
      influencer:         "フォロワーを増やしたい"
    }[purpose.to_sym]
  end
end
