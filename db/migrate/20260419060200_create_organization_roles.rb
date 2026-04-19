# Phase 44d / §19: 組織ロール定義マスタ。
# MeetingDefinition の participant_roles（JSONB 文字列配列）をマスタテーブルで検証可能にする。
class CreateOrganizationRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_roles, if_not_exists: true do |t|
      t.string  :role_key,    null: false  # ユニークキー（例: "planning", "dev"）
      t.string  :display_name, null: false # 表示名
      t.integer :scope_level,  null: false # enum: company/portfolio/service/cross_service
      t.integer :category,     null: false, default: 0 # enum: executive/department/specialist
      t.boolean :active,       null: false, default: true
      t.text    :description               # ロール説明（任意）

      t.timestamps
    end

    add_index :organization_roles, :role_key, unique: true, if_not_exists: true
    add_index :organization_roles, :active, if_not_exists: true
    add_index :organization_roles, :scope_level, if_not_exists: true
  end
end
