job = MarketAnalysisJob.new
def job.market_open?
  true
end
job.perform
puts "完了"
