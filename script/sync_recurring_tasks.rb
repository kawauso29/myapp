SolidQueue::RecurringTask.destroy_all

config = Rails.application.config_for("recurring")
config.each do |key, opts|
  next unless opts[:schedule]
  SolidQueue::RecurringTask.find_or_create_by!(key: key.to_s) do |t|
    t.schedule    = opts[:schedule]
    t.command     = opts[:command]
    t.class_name  = opts[:class]
    t.queue_name  = opts[:queue]
    t.priority    = opts[:priority] || 0
    t.description = opts[:description]
  end
end

puts "登録済みタスク:"
puts SolidQueue::RecurringTask.pluck(:key)
