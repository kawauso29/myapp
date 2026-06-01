# frozen_string_literal: true

namespace :linestamp do
  desc "ブランド間で識別軸(シルエット/シグネチャー/占有色)が被っていないか検査する。被りは「またかわいい動物量産」の兆候。"
  task brand_collision: :environment do
    axes = {
      "silhouette"      => "シルエット/頭身",
      "signature"       => "シグネチャー(必ず出す識別要素)",
      "signature_color" => "占有色"
    }

    normalize = ->(text) {
      text.to_s
          .unicode_normalize(:nfkc)
          .downcase
          .gsub(/[[:space:]]/, "")
          .gsub(/[、。,.\/()()「」\-_]/, "")
    }

    brands = Linestamp::Brand.order(:id).to_a
    if brands.size < 2
      puts "ブランドが #{brands.size} 件のみ。衝突検査には2件以上必要です。"
      next
    end

    puts "=== Linestamp ブランド識別軸 衝突レポート (#{brands.size} brands) ==="
    collisions = 0

    axes.each do |key, label|
      rows = brands.map { |b|
        raw = (b.identity_axes || {})[key].to_s.strip
        { brand: b, raw: raw, norm: normalize.call(raw) }
      }

      hits = []
      rows.each_with_index do |a, i|
        next if a[:norm].blank?

        rows[(i + 1)..].each do |c|
          next if c[:norm].blank?

          same = a[:norm] == c[:norm]
          contained = a[:norm].include?(c[:norm]) || c[:norm].include?(a[:norm])
          hits << [a, c, same ? "完全一致" : "包含"] if same || contained
        end
      end

      next if hits.empty?

      puts "\n■ #{label}（#{key}）の被り:"
      hits.each do |a, c, kind|
        collisions += 1
        puts "  [#{kind}] #{a[:brand].character_name}: \"#{a[:raw]}\""
        puts "          ↕ #{c[:brand].character_name}: \"#{c[:raw]}\""
      end
    end

    # primary_color(列)の完全一致も占有色の被りとして検出する。
    color_groups = brands.group_by { |b| b.primary_color.to_s.downcase.strip }
                         .reject { |hex, _| hex.blank? }
    color_groups.each do |hex, list|
      next if list.size < 2

      collisions += 1
      puts "\n■ primary_color #{hex} を複数ブランドが使用:"
      list.each { |b| puts "  - #{b.character_name}" }
    end

    puts "\n=== 検出: #{collisions} 件の被り ==="
    if collisions.zero?
      puts "識別軸の衝突なし。各ブランドは黒塗りシルエット・シグネチャー・占有色で区別可能です。"
    else
      puts "⚠ 上記を解消してから新ブランドを増やすこと(またかわいい動物化の防止)。"
    end
  end
end
