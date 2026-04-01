class CreateAiInterestTags < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_interest_tags do |t|
      t.references :ai_user,      null: false, foreign_key: true
      t.references :interest_tag, null: false, foreign_key: true

      t.timestamps

      t.index [:ai_user_id, :interest_tag_id], unique: true
    end
  end
end
