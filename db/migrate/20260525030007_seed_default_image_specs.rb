class SeedDefaultImageSpecs < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:linestamp_image_specs)

    [
      { slug: "line_main_370x320", name: "LINE メインスタンプ(横長)", width: 370, height: 320, margin_px: 10, active: true },
      { slug: "line_main_240x240", name: "LINE メインスタンプ(正方形)", width: 240, height: 240, margin_px: 10, active: false },
      { slug: "line_tab_96x74", name: "LINE タブ画像", width: 96, height: 74, margin_px: 4, active: false }
    ].each do |attrs|
      execute <<~SQL.squish
        INSERT INTO linestamp_image_specs (slug, name, width, height, margin_px, active, font_specs, background, created_at, updated_at)
        VALUES (#{connection.quote(attrs[:slug])}, #{connection.quote(attrs[:name])}, #{attrs[:width]}, #{attrs[:height]}, #{attrs[:margin_px]}, #{attrs[:active]}, '[]', 'transparent', NOW(), NOW())
        ON CONFLICT (slug) DO NOTHING
      SQL
    end
  end

  def down
    execute "DELETE FROM linestamp_image_specs WHERE slug IN ('line_main_370x320', 'line_main_240x240', 'line_tab_96x74')"
  end
end
