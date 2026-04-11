class AddPersonalityFields < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_personalities, :patience,           :integer, default: 3, null: false
    add_column :ai_personalities, :optimism,           :integer, default: 3, null: false
    add_column :ai_personalities, :creativity,         :integer, default: 3, null: false
    add_column :ai_personalities, :independence,       :integer, default: 3, null: false
    add_column :ai_personalities, :trustfulness,       :integer, default: 3, null: false
    add_column :ai_personalities, :competitiveness,    :integer, default: 3, null: false
    add_column :ai_personalities, :sensitivity,        :integer, default: 3, null: false
    add_column :ai_personalities, :humor,              :integer, default: 3, null: false
    add_column :ai_personalities, :nostalgia_tendency, :integer, default: 3, null: false
    add_column :ai_personalities, :perfectionism,      :integer, default: 3, null: false
    add_column :ai_personalities, :stubbornness,       :integer, default: 3, null: false
    add_column :ai_personalities, :generosity,         :integer, default: 3, null: false
  end
end
