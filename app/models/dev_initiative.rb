class DevInitiative < ApplicationRecord
  enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true
  enum :status, { todo: 0, in_progress: 1, done: 2 }, prefix: true

  validates :item_key, presence: true, uniqueness: true
  validates :title, presence: true
  validates :priority, :status, presence: true

  scope :ordered, -> { order(priority: :desc, item_key: :asc) }
  scope :next_todo, -> { status_todo.ordered }
end
