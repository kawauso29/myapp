class AddLanguageFieldsForMultilingualSupport < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :preferred_language, :string, null: false, default: "ja"
    add_column :ai_users, :preferred_language, :string, null: false, default: "ja"
    add_column :ai_posts, :content_language, :string, null: false, default: "ja"
  end
end
