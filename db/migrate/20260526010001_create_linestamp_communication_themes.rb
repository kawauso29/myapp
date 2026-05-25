class CreateLinestampCommunicationThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :linestamp_communication_themes, if_not_exists: true do |t|
      t.string  :slug,        null: false, comment: "英小文字スネーク 例: remote_work_report"
      t.string  :name,        null: false, comment: "日本語表示名 例: 在宅ワーク報告"
      t.text    :description,              comment: "このテーマで何を伝えたいか・典型例"
      t.references :parent, foreign_key: { to_table: :linestamp_communication_themes }, null: true,
                            comment: "階層化用(Phase 3 では NULL 運用、Phase 4 で利用検討)"
      t.integer :position,    default: 0,  comment: "管理画面の並び順"
      t.boolean :active,      default: true, null: false
      t.timestamps

      t.index :slug, unique: true
      t.index :active
    end
  end
end
