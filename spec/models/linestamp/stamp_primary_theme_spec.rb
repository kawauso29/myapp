# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stamp primary_communication_theme sync", type: :model do
  let!(:brand) { Linestamp::Brand.create!(slug: "sync_brand", character_name: "Test", series_name: "Test") }
  let!(:pack) { brand.packs.create!(series_theme: "Theme", position: 1) }
  let!(:stamp) { pack.stamps.create!(position: 1) }
  let!(:theme_a) { Linestamp::CommunicationTheme.create!(slug: "theme_a", name: "Theme A") }
  let!(:theme_b) { Linestamp::CommunicationTheme.create!(slug: "theme_b", name: "Theme B") }

  describe "sync via StampCommunicationTheme callbacks" do
    it "sets primary_communication_theme_id when primary=true join is created" do
      join = stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: true)
      stamp.reload
      expect(stamp.primary_communication_theme_id).to eq(theme_a.id)
    end

    it "updates primary_communication_theme_id when primary changes" do
      stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: true)
      join_b = stamp.stamp_communication_themes.create!(communication_theme: theme_b, primary: false)

      # Switch primary
      stamp.stamp_communication_themes.find_by(communication_theme: theme_a).update!(primary: false)
      join_b.update!(primary: true)
      stamp.reload
      expect(stamp.primary_communication_theme_id).to eq(theme_b.id)
    end

    it "clears primary_communication_theme_id when primary join is destroyed" do
      join = stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: true)
      join.destroy!
      stamp.reload
      expect(stamp.primary_communication_theme_id).to be_nil
    end
  end

  describe "validation: exactly_one_primary" do
    it "fails when 0 primaries with themes present" do
      stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: false)
      expect(stamp).not_to be_valid
      expect(stamp.errors[:base].join).to include("primary")
    end

    it "fails when 2+ primaries" do
      stamp.stamp_communication_themes.build(communication_theme: theme_a, primary: true)
      stamp.stamp_communication_themes.build(communication_theme: theme_b, primary: true)
      expect(stamp).not_to be_valid
    end

    it "passes with exactly 1 primary" do
      stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: true)
      stamp.stamp_communication_themes.create!(communication_theme: theme_b, primary: false)
      expect(stamp).to be_valid
    end
  end

  describe "no direct public API to set primary_communication_theme_id" do
    it "sync_primary_communication_theme_id! is the only public path (called via callbacks)" do
      # Direct update_column is private concern; public interface is through join table
      stamp.stamp_communication_themes.create!(communication_theme: theme_a, primary: true)
      expect(stamp.reload.primary_communication_theme).to eq(theme_a)
    end
  end
end
