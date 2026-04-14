# frozen_string_literal: true

class CreateAiCommunities < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_communities do |t|
      t.string :name, null: false
      t.string :description
      t.string :category
      t.string :emoji, default: "👥"
      t.integer :members_count, default: 0, null: false

      t.timestamps
    end

    add_index :ai_communities, :name, unique: true
    add_index :ai_communities, :members_count

    create_table :ai_community_memberships do |t|
      t.references :ai_community, null: false, foreign_key: true
      t.references :ai_user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :ai_community_memberships, %i[ai_community_id ai_user_id], unique: true,
              name: "index_community_memberships_unique"

    create_table :user_community_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ai_community, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_community_follows, %i[user_id ai_community_id], unique: true,
              name: "index_user_community_follows_unique"
  end
end
