# frozen_string_literal: true

class CreateLinestampSeedApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :linestamp_seed_applications, if_not_exists: true do |t|
      t.string :seed_id, null: false
      t.string :file_path
      t.string :file_sha256
      t.string :state, null: false, default: "pending"
      t.text :result_summary
      t.text :error_message
      t.datetime :applied_at

      t.timestamps
    end

    add_index :linestamp_seed_applications, :seed_id, unique: true, if_not_exists: true
    add_index :linestamp_seed_applications, :state, if_not_exists: true
  end
end
