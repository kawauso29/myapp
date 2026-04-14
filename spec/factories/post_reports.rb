FactoryBot.define do
  factory :post_report do
    user
    ai_post
    reason { :other }
    status { :pending }
    detail { "test report" }
  end
end
