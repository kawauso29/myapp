# frozen_string_literal: true

require "rails_helper"

RSpec.describe Linestamp::PromptComposer do
  before do
    load Rails.root.join("db/seeds/linestamp/masters.rb")
    Linestamp::Seeds.call
  end

  let(:brand) do
    Linestamp::Brand.create!(
      slug: "nekochan",
      character_name: "ねこちゃん",
      series_name: "オフィスのねこちゃん",
      persona_name: "オフィスワーカー佐藤さん(30代女性)",
      two_part_definition: "ねこちゃんは「甘えん坊な猫」ではない。ねこちゃんは、無関心だけど時々気を遣う、オフィスにいる猫である。",
      tone_axes: { gentle: 0.95, cute: 0.7 },
      character_parts: { eyes: "ジト目", mouth: "横一文字", ears: "三角の小さい耳", body: "白い2頭身", limbs: "短い手足", tail: "細い尾", collar: "ピンクの首輪" },
      font_spec: { "primary" => "丸ゴシック太め", "color" => "#3D2817", "outline" => "white_thick_4px" },
      background_color_for_gen: "#3CB371",
      primary_color: "#FFFFFF"
    )
  end

  # CT/属性をアタッチ
  before do
    # CTs
    %w[agreement appreciation_for_effort friendly_tease need_focus quick_answer].each do |slug|
      ct = Linestamp::CommunicationTheme.find_by!(slug: slug)
      brand.brand_communication_themes.find_or_create_by!(communication_theme: ct)
    end
    # Attributes
    %w[cute stylish].each do |slug|
      av = Linestamp::AttributeValue.find_by!(slug: slug)
      brand.brand_attribute_values.find_or_create_by!(attribute_value: av)
    end
    av_animal = Linestamp::AttributeValue.find_by!(slug: "animal")
    brand.brand_attribute_values.find_or_create_by!(attribute_value: av_animal)
    av_office = Linestamp::AttributeValue.find_by!(slug: "office")
    brand.brand_attribute_values.find_or_create_by!(attribute_value: av_office)
  end

  let(:pack) do
    brand.packs.create!(
      slug: "core_office",
      series_theme: "オフィスの定番",
      position: 1,
      layer: "core_work",
      world_view: "オフィスの自席で同僚・上司との会話に添える、カジュアルなリアクション集",
      usage_scenes: ["朝の挨拶", "会議の合間", "コーヒー休憩", "終業前のひと息"],
      target_emotions: ["相槌", "軽いねぎらい", "気遣い", "集中したい合図"],
      excluded_elements: "週末・恋人との会話(Dream Layer 派生パックで使用予定)"
    )
  end

  let!(:stamp_greeting) do
    ct = Linestamp::CommunicationTheme.find_by!(slug: "greeting_morning")
    pack.stamps.create!(
      position: 1,
      label: "おはよう",
      situation: "朝の自席。マグカップを抱えて目を細める",
      intent: "朝の挨拶をカジュアルに",
      usage_scene: "出社直後のチャット",
      pose_spec: "座り、マグ抱え",
      props: "マグカップ",
      communication_purpose: "テキストなしで朝の挨拶を済ませる",
      primary_communication_theme: ct,
      skip_primary_theme_guard: true
    )
  end

  let!(:stamp_roger) do
    ct = Linestamp::CommunicationTheme.find_by!(slug: "agreement")
    pack.stamps.create!(
      position: 2,
      label: "りょうかい",
      situation: "PC前で軽く手を上げる。視線は画面のまま",
      intent: "メッセージを確認した合図",
      usage_scene: "業務チャットで指示を受けた直後",
      pose_spec: "座り、片手だけ顔の横に上げる",
      props: "ノートPC",
      communication_purpose: "タイプする時間がない時の「読んだよ」",
      primary_communication_theme: ct,
      skip_primary_theme_guard: true
    )
  end

  let(:composer) { described_class.new }

  describe "#compose_brand_prompt" do
    subject(:prompt) { composer.compose_brand_prompt(brand) }

    it "includes two-part definition" do
      expect(prompt).to include("ねこちゃんは「甘えん坊な猫」ではない")
    end

    it "includes persona name" do
      expect(prompt).to include("オフィスワーカー佐藤さん")
    end

    it "includes CT names from master" do
      expect(prompt).to include("相槌")
    end

    it "includes attribute values from master (tone)" do
      expect(prompt).to include("かわいい")
    end

    it "includes setting attribute" do
      expect(prompt).to include("オフィス")
    end

    it "includes character parts" do
      expect(prompt).to include("ジト目")
      expect(prompt).to include("ピンクの首輪")
    end

    it "includes font spec" do
      expect(prompt).to include("丸ゴシック太め")
      expect(prompt).to include("#3D2817")
    end

    it "includes background color" do
      expect(prompt).to include("#3CB371")
    end

    it "includes guard instructions" do
      expect(prompt).to include("白背景禁止")
      expect(prompt).to include("キャラの解釈を加えない")
    end
  end

  describe "#compose_pack_prompt" do
    subject(:prompt) { composer.compose_pack_prompt(pack) }

    it "includes series theme" do
      expect(prompt).to include("オフィスの定番")
    end

    it "includes world view" do
      expect(prompt).to include("カジュアルなリアクション集")
    end

    it "includes usage scenes" do
      expect(prompt).to include("朝の挨拶")
    end

    it "includes target emotions" do
      expect(prompt).to include("軽いねぎらい")
    end

    it "includes excluded elements" do
      expect(prompt).to include("Dream Layer")
    end

    it "includes stamp entries with CT names" do
      expect(prompt).to include("おはよう")
      expect(prompt).to include("りょうかい")
    end

    it "includes guard instructions" do
      expect(prompt).to include("キャラの揺れ")
      expect(prompt).to include("ひらがな逃げ禁止")
    end
  end

  describe "#compose_pack_sheet_prompt (alias)" do
    it "is an alias for compose_pack_prompt" do
      expect(composer.method(:compose_pack_sheet_prompt)).to eq(composer.method(:compose_pack_prompt))
    end
  end

  describe "#compose_stamp_prompt" do
    subject(:prompt) { composer.compose_stamp_prompt(stamp_roger) }

    it "includes stamp label" do
      expect(prompt).to include("りょうかい")
    end

    it "includes primary CT name and description" do
      expect(prompt).to include("相槌")
    end

    it "includes situation" do
      expect(prompt).to include("PC前で軽く手を上げる")
    end

    it "includes pose spec" do
      expect(prompt).to include("座り、片手だけ顔の横に上げる")
    end

    it "includes intent" do
      expect(prompt).to include("メッセージを確認した合図")
    end

    it "includes communication purpose" do
      expect(prompt).to include("タイプする時間がない時")
    end

    it "includes background color" do
      expect(prompt).to include("#3CB371")
    end

    it "includes guard instructions" do
      expect(prompt).to include("ひらがなに逃げない")
      expect(prompt).to include("80%")
    end
  end
end
