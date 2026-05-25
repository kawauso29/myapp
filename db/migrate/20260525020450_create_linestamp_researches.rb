class CreateLinestampResearches < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_researches, if_not_exists: true do |t|
      t.string :title, null: false
      t.text :body
      t.string :source_url
      t.string :status, default: "draft", null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :linestamp_researches, :status, if_not_exists: true
  end
end
