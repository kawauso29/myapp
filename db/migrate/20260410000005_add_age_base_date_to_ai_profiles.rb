class AddAgeBaseDateToAiProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_profiles, :age_base_date, :date
  end
end
