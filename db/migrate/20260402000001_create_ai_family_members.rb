class CreateAiFamilyMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_family_members do |t|
      t.references :ai_user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :relationship, null: false  # enum: partner/child/parent/sibling
      t.integer :birth_year                 # nil for unknown
      t.text :notes                         # e.g. "保育園に通っている", "中学2年生"

      t.timestamps
    end
  end
end
