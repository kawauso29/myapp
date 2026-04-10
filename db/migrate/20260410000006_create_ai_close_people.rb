class CreateAiClosePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_close_people do |t|
      t.references :ai_user, null: false, foreign_key: true
      t.string  :name,         null: false
      t.integer :relation,     null: false  # enum: spouse/partner/child/parent/sibling/friend/colleague/other
      t.integer :age                        # 基準年齢（nil = 不明）
      t.date    :age_base_date              # 年齢起算日（nilなら固定値）
      t.integer :gender                     # enum: male/female/other/unspecified
      t.text    :notes                      # 補足情報

      t.timestamps
    end

    add_index :ai_close_people, [:ai_user_id, :relation]
  end
end
