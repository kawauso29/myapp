class CreateAiProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_profiles do |t|
      t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

      t.string  :name,              null: false
      t.integer :age,               null: false
      t.integer :gender
      t.string  :occupation
      t.integer :occupation_type
      t.string  :location
      t.text    :bio

      t.integer :life_stage
      t.integer :family_structure
      t.integer :num_children,      null: false, default: 0
      t.integer :youngest_child_age
      t.integer :relationship_status

      t.string  :favorite_foods,              array: true, default: []
      t.string  :favorite_music,              array: true, default: []
      t.string  :hobbies,                     array: true, default: []
      t.string  :favorite_places,             array: true, default: []

      t.string  :strengths,                   array: true, default: []
      t.string  :weaknesses,                  array: true, default: []
      t.string  :values,                      array: true, default: []
      t.string  :disliked_personality_types,  array: true, default: []
      t.string  :catchphrase

      t.text    :personality_note

      t.timestamps
    end
  end
end
