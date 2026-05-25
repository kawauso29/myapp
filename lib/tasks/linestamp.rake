namespace :linestamp do
  desc "Sync brand_sources/ directory to DB"
  task sync: :environment do
    syncer = Linestamp::BrandSourcesSyncer.new
    syncer.sync_all
    puts "Linestamp brand sources synced."
  end

  desc "Seed nemuinu brand with initial data"
  task seed_nemuinu: :environment do
    brand = Linestamp::Seeders::Nemuinu.new.seed!
    puts "Seeded nemuinu brand: id=#{brand.id}, packs=#{brand.packs.count}, stamps=#{brand.packs.sum { |p| p.stamps.count }}"
  end
end
