class AddBaseCompositionsToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :linestamp_brands, :base_compositions, :jsonb, default: []
  end
end
