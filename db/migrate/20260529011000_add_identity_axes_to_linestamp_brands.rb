class AddIdentityAxesToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :linestamp_brands, :identity_axes, :jsonb, default: {}
  end
end
