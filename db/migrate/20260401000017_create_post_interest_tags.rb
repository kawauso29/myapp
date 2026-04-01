class CreatePostInterestTags < ActiveRecord::Migration[8.1]
  def change
    create_table :post_interest_tags do |t|
      t.references :ai_post,      null: false, foreign_key: true
      t.references :interest_tag, null: false, foreign_key: true

      t.timestamps

      t.index [:ai_post_id, :interest_tag_id], unique: true
    end
  end
end
