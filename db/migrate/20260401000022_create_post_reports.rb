class CreatePostReports < ActiveRecord::Migration[8.1]
  def change
    create_table :post_reports do |t|
      t.references :user,    null: false, foreign_key: true
      t.references :ai_post, null: false, foreign_key: true

      t.integer :reason, null: false
      t.text    :detail
      t.integer :status, null: false, default: 0

      t.timestamps

      t.index [:ai_post_id, :status]
      t.index :status
    end
  end
end
