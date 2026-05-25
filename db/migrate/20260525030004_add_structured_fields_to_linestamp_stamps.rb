class AddStructuredFieldsToLinestampStamps < ActiveRecord::Migration[8.1]
  def change
    change_table :linestamp_stamps do |t|
      t.string :label
      t.text   :situation
      t.text   :intent
      t.text   :usage_scene
      t.jsonb  :search_keywords, default: []
      t.text   :communication_purpose
      t.text   :pose_spec
      t.text   :props
    end
  end
end
