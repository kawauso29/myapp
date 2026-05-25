class AddPrimaryCommunicationThemeToLinestampStamps < ActiveRecord::Migration[8.1]
  def change
    add_reference :linestamp_stamps, :primary_communication_theme,
                  foreign_key: { to_table: :linestamp_communication_themes },
                  null: true,
                  comment: "stamp の主テーマ(中間表の primary=true と必ず一致させる)"
    add_index :linestamp_stamps, :primary_communication_theme_id,
              name: "idx_stamps_by_primary_ct"
  end
end
