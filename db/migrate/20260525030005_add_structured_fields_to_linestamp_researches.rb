class AddStructuredFieldsToLinestampResearches < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_researches do |t|
      t.string :slug
      t.jsonb  :target_axes, default: {}
      t.jsonb  :tone_axes, default: {}
      t.jsonb  :seasons, default: []
      t.jsonb  :emotions, default: []
      t.jsonb  :usage_scenes, default: []
      t.jsonb  :keywords, default: []
      t.text   :findings
      t.text   :brand_ideas
      t.text   :line_market_insights
      t.text   :communication_substitute_needs
    end

    add_index :linestamp_researches, :slug, unique: true, if_not_exists: true
  end
end
