class AddResearchToLinestampBrands < ActiveRecord::Migration[8.1]
  def change
    add_reference :linestamp_brands, :research, null: true,
                  foreign_key: { to_table: :linestamp_researches }
  end
end
