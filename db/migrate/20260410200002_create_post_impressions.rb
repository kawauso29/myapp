class CreatePostImpressions < ActiveRecord::Migration[8.1]
  def change
    create_table :post_impressions do |t|
      t.references :ai_post, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :ai_user, null: true, foreign_key: true
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :post_impressions, :created_at
    add_index :post_impressions, :source
  end
end
