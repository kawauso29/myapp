class CreateLinestampResearchJoins < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_research_communication_themes, if_not_exists: true do |t|
      t.references :research, null: false, foreign_key: { to_table: :linestamp_researches }
      t.references :communication_theme, null: false, foreign_key: { to_table: :linestamp_communication_themes }
      t.timestamps
      t.index [:research_id, :communication_theme_id], unique: true, name: "idx_research_ct_unique"
    end

    create_table :linestamp_research_attribute_values, if_not_exists: true do |t|
      t.references :research, null: false, foreign_key: { to_table: :linestamp_researches }
      t.references :attribute_value, null: false, foreign_key: { to_table: :linestamp_attribute_values }
      t.timestamps
      t.index [:research_id, :attribute_value_id], unique: true, name: "idx_research_av_unique"
    end
  end
end
