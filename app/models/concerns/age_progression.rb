module AgeProgression
  extend ActiveSupport::Concern

  # 1ヶ月で1歳進む時間加速設定
  # age_base_date が設定されていれば、そこからの経過月数を年齢に加算する
  def current_age
    return age unless age_base_date.present? && age.present?

    months_elapsed = (Date.current.year * 12 + Date.current.month) -
                     (age_base_date.year * 12 + age_base_date.month)
    age + months_elapsed
  end
end
