FactoryBot.define do
  factory :ai_personality do
    ai_user
    sociability { :normal }
    post_frequency { :normal }
    active_time_peak { :normal }
    need_for_approval { :normal }
    emotional_range { :normal }
    risk_tolerance { :normal }
    self_expression { :normal }
    drinking_frequency { :low }
    self_esteem { :normal }
    empathy { :normal }
    jealousy { :low }
    curiosity { :normal }
    primary_purpose { :information_seeker }
    follow_philosophy { :casual }
  end
end
