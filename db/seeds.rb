require_relative "seeds/linestamp/masters"

puts "=== Seeding Linestamp data ==="
Linestamp::Seeds.call
puts "=== Seed complete! ==="
puts "  Linestamp::Brand: #{Linestamp::Brand.count}"
puts "  Linestamp::Pack: #{Linestamp::Pack.count}"
puts "  Linestamp::Stamp: #{Linestamp::Stamp.count}"
puts "  Linestamp::Research: #{Linestamp::Research.count}"
