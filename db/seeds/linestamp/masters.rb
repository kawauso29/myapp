# frozen_string_literal: true

# Linestamp master data seed (idempotent)
# Usage: require from db/seeds.rb or run standalone

module Linestamp
  module Seeds
    module_function

    def call
      seed_attribute_axes
      seed_attribute_values
      seed_communication_themes
      puts "  Linestamp masters seeded: #{Linestamp::AttributeAxis.count} axes, #{Linestamp::AttributeValue.count} values, #{Linestamp::CommunicationTheme.count} themes"
    end

    def seed_attribute_axes
      axes = [
        { slug: "tone",        name: "トーン",       kind: "tone",        position: 1 },
        { slug: "motif",       name: "モチーフ",     kind: "motif",       position: 2 },
        { slug: "demographic", name: "デモグラフィ", kind: "demographic", position: 3 },
        { slug: "setting",     name: "シーン",       kind: "setting",     position: 4 }
      ]
      axes.each do |attrs|
        Linestamp::AttributeAxis.find_or_create_by!(slug: attrs[:slug]) do |ax|
          ax.assign_attributes(attrs.except(:slug))
        end
      end
    end

    def seed_attribute_values
      values = [
        # tone
        { axis_slug: "tone", slug: "gentle",  name: "ゆるい",     position: 1 },
        { axis_slug: "tone", slug: "neat",    name: "きっちり",   position: 2 },
        { axis_slug: "tone", slug: "surreal", name: "シュール",   position: 3 },
        { axis_slug: "tone", slug: "cute",    name: "かわいい",   position: 4 },
        { axis_slug: "tone", slug: "cool",    name: "かっこいい", position: 5 },
        { axis_slug: "tone", slug: "stylish", name: "おしゃれ",   position: 6 },
        { axis_slug: "tone", slug: "funny",   name: "おもしろい", position: 7 },
        { axis_slug: "tone", slug: "elegant", name: "上品",       position: 8 },
        # motif
        { axis_slug: "motif", slug: "animal",   name: "動物",       position: 1 },
        { axis_slug: "motif", slug: "food",     name: "食べ物",     position: 2 },
        { axis_slug: "motif", slug: "plant",    name: "植物",       position: 3 },
        { axis_slug: "motif", slug: "human",    name: "人物",       position: 4 },
        { axis_slug: "motif", slug: "monster",  name: "モンスター", position: 5 },
        { axis_slug: "motif", slug: "abstract", name: "抽象",       position: 6 },
        { axis_slug: "motif", slug: "vehicle",  name: "乗り物",     position: 7 },
        { axis_slug: "motif", slug: "tool",     name: "道具",       position: 8 },
        # demographic
        { axis_slug: "demographic", slug: "age_10s",       name: "10代",       position: 1 },
        { axis_slug: "demographic", slug: "age_20s",       name: "20代",       position: 2 },
        { axis_slug: "demographic", slug: "age_30s",       name: "30代",       position: 3 },
        { axis_slug: "demographic", slug: "age_40s",       name: "40代",       position: 4 },
        { axis_slug: "demographic", slug: "age_50plus",    name: "50代以上",   position: 5 },
        { axis_slug: "demographic", slug: "for_male",      name: "男性向け",   position: 6 },
        { axis_slug: "demographic", slug: "for_female",    name: "女性向け",   position: 7 },
        { axis_slug: "demographic", slug: "unisex",        name: "性別不問",   position: 8 },
        { axis_slug: "demographic", slug: "business_user", name: "ビジネス層", position: 9 },
        { axis_slug: "demographic", slug: "student",       name: "学生",       position: 10 },
        # setting
        { axis_slug: "setting", slug: "home",             name: "家庭",     position: 1 },
        { axis_slug: "setting", slug: "remote_work",      name: "在宅",     position: 2 },
        { axis_slug: "setting", slug: "office",           name: "オフィス", position: 3 },
        { axis_slug: "setting", slug: "with_friends",     name: "友達同士", position: 4 },
        { axis_slug: "setting", slug: "with_lover",       name: "恋人",     position: 5 },
        { axis_slug: "setting", slug: "with_family",      name: "家族",     position: 6 },
        { axis_slug: "setting", slug: "boss_subordinate", name: "上司部下", position: 7 },
        { axis_slug: "setting", slug: "with_customer",    name: "お客様",   position: 8 }
      ]

      values.each do |attrs|
        axis = Linestamp::AttributeAxis.find_by!(slug: attrs[:axis_slug])
        Linestamp::AttributeValue.find_or_create_by!(axis: axis, slug: attrs[:slug]) do |av|
          av.assign_attributes(attrs.except(:axis_slug, :slug))
        end
      end
    end

    def seed_communication_themes
      themes = [
        { slug: "remote_work_report",     name: "在宅ワーク報告",   description: "在宅勤務中の状況を相手に伝える",       position: 1 },
        { slug: "gratitude",              name: "感謝",             description: "ありがとうの気持ちを伝える",           position: 2 },
        { slug: "apology",               name: "謝罪",             description: "申し訳なさを和らげて伝える",           position: 3 },
        { slug: "agreement",             name: "相槌",             description: "了解・OK・うん",                       position: 4 },
        { slug: "encouragement",         name: "励まし",           description: "相手を元気づける",                     position: 5 },
        { slug: "greeting_morning",      name: "おはよう",         description: "朝の挨拶",                             position: 6 },
        { slug: "greeting_night",        name: "おやすみ",         description: "夜の挨拶",                             position: 7 },
        { slug: "confirm_meetup",        name: "待ち合わせ確認",   description: "今どこ?何時?",                         position: 8 },
        { slug: "on_the_way",            name: "今行く",           description: "移動中の連絡",                         position: 9 },
        { slug: "meal_invitation",       name: "食事の誘い",       description: "ご飯行こう",                           position: 10 },
        { slug: "friendly_tease",        name: "相手をいじる",     description: "軽い冗談・からかい",                   position: 11 },
        { slug: "appreciation_for_effort", name: "ねぎらい",       description: "お疲れさま系",                         position: 12 },
        { slug: "need_focus",            name: "集中したい",       description: "今は構わないで",                       position: 13 },
        { slug: "need_break",            name: "休憩したい",       description: "ちょっと休む",                         position: 14 },
        { slug: "quick_answer",          name: "簡易回答",         description: "はい/いいえ/わかった",                 position: 15 },
        { slug: "urgent_contact",        name: "緊急連絡",         description: "すぐ確認して系",                       position: 16 },
        { slug: "status_busy",           name: "忙しいアピール",   description: "今手が離せない",                       position: 17 },
        { slug: "celebration",           name: "お祝い",           description: "おめでとう",                           position: 18 }
      ]

      themes.each do |attrs|
        Linestamp::CommunicationTheme.find_or_create_by!(slug: attrs[:slug]) do |ct|
          ct.assign_attributes(attrs.except(:slug))
        end
      end
    end
  end
end

Linestamp::Seeds.call if $PROGRAM_NAME == __FILE__ || (defined?(Rails) && !Rails.env.test?)
