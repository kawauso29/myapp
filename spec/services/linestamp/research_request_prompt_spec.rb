# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::ResearchRequestPrompt do
  before do
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call
  end

  subject(:composer) { described_class.new(target_date: Date.new(2026, 6, 15)) }

  describe "#week_label / #research_slug / #target_range" do
    it "ISO週とレンジを算出する" do
      expect(composer.week_label).to eq("2026-W25")
      expect(composer.research_slug).to eq("weekly_trends_2026_w25")
      expect(composer.target_range).to eq("6/15〜6/21")
    end
  end

  describe "#compose" do
    let(:research) do
      Linestamp::Research.create!(slug: "weekly_trends_2026_w24", title: "週次調査 W24")
    end

    let(:brand) do
      b = Linestamp::Brand.create!(
        slug: "moka_kuma",
        character_name: "モカ",
        series_name: "モカのシリーズ",
        identity_axes: { "silhouette" => "2頭身の丸い相棒", "signature_color" => "#F6E7D8" },
        primary_color: "#F6E7D8"
      )
      ct = Linestamp::CommunicationTheme.find_by!(slug: "gratitude")
      b.brand_communication_themes.create!(communication_theme: ct)
      b
    end

    before do
      research
      brand
    end

    it "対象週・既存ブランド・調査履歴・slug辞書を注入する" do
      prompt = composer.compose

      expect(prompt).to include("対象週: 2026-W25(6/15〜6/21)")
      # 既存ブランドの差別化情報
      expect(prompt).to include("moka_kuma")
      expect(prompt).to include("2頭身の丸い相棒")
      expect(prompt).to include("#F6E7D8")
      # 調査履歴(重複回避)
      expect(prompt).to include("weekly_trends_2026_w24: 週次調査 W24")
      # master slug 辞書
      expect(prompt).to include("gratitude")
      expect(prompt).to include("tone:")
      # 出力フォーマット
      expect(prompt).to include('Linestamp::Importer.run')
      expect(prompt).to include("imports/pending/")
    end

    it "件数を数えられる" do
      expect(composer.brands_count).to eq(1)
      expect(composer.researches_count).to eq(1)
    end
  end
end
