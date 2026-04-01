class AddExpoPushTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :expo_push_token, :string
    add_index :users, :expo_push_token
  end
end
