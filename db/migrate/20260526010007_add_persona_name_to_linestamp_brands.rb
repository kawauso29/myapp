class AddPersonaNameToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :linestamp_brands, :persona_name, :string,
               comment: "ペルソナの通称(社内コミュニケーション用)例: 在宅ワーカー田中さん"
  end
end
