class CreatePicroMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :picro_messages do |t|
      t.string :message_id, null: false
      t.string :sender_name
      t.string :title
      t.text :preview
      t.boolean :notified, null: false, default: false
      t.datetime :received_at

      t.timestamps
    end

    add_index :picro_messages, :message_id, unique: true
  end
end
