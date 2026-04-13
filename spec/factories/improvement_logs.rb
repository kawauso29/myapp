FactoryBot.define do
  factory :improvement_log do
    observation        { { "totals" => { "posts_24h" => 10 } } }
    summary            { "AI SNS の観察データから改善提案を整理しました" }
    quick_win_results  { [] }
    feature_proposals  { [] }
    applied_quick_wins { 0 }
    created_pr_numbers { [] }
  end
end
