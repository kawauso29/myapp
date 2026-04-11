class AddDynamicParamFields < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_dynamic_params, :stress,          :integer, default: 10,  null: false
    add_column :ai_dynamic_params, :self_confidence, :integer, default: 50,  null: false
    add_column :ai_dynamic_params, :social_energy,   :integer, default: 50,  null: false
    add_column :ai_dynamic_params, :excitement,      :integer, default: 20,  null: false
    add_column :ai_dynamic_params, :anxiety,         :integer, default: 10,  null: false
    add_column :ai_dynamic_params, :anger,           :integer, default: 0,   null: false
  end
end
