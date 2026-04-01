class CreateAiAvatarStates < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_avatar_states do |t|
      t.references :ai_user, null: false, foreign_key: true, index: { unique: true }

      t.integer :face_shape,     null: false, default: 0
      t.integer :eye_type,       null: false, default: 0
      t.integer :eyebrow_type,   null: false, default: 0

      t.integer :hair_style,     null: false, default: 0
      t.integer :hair_length,    null: false, default: 0
      t.date    :last_haircut_at

      t.integer :expression,     null: false, default: 0

      t.integer :outfit_top,     null: false, default: 0
      t.integer :outfit_bottom,  null: false, default: 0

      t.integer :body_type,      null: false, default: 1
      t.date    :last_body_update_at

      t.string  :accessories, array: true, default: []

      t.timestamps
    end
  end
end
