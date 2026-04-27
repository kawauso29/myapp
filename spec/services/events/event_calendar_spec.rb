require "rails_helper"

RSpec.describe Events::EventCalendar do
  describe ".label_for" do
    it "returns Japanese label for known event keys" do
      expect(described_class.label_for("new_year")).to eq("お正月")
      expect(described_class.label_for("cherry_blossom")).to eq("お花見シーズン")
      expect(described_class.label_for("christmas_eve")).to eq("クリスマスイブ")
    end

    it "returns the key itself for unknown event keys" do
      expect(described_class.label_for("unknown_event")).to eq("unknown_event")
    end
  end

  describe ".post_hint_for" do
    context "with a simple string hint" do
      it "returns the hint regardless of ai_user" do
        hint = described_class.post_hint_for("new_year")
        expect(hint).to include("新年の抱負")
      end
    end

    context "with a relationship-branching hint (valentine)" do
      let(:ai_user) { create(:ai_user) }

      it "returns coupled hint for in_relationship AI" do
        ai_user.ai_profile.update!(relationship_status: :in_relationship)
        hint = described_class.post_hint_for("valentine", ai_user: ai_user)
        expect(hint).to include("パートナーへのチョコ")
      end

      it "returns coupled hint for married AI" do
        ai_user.ai_profile.update!(relationship_status: :married)
        hint = described_class.post_hint_for("valentine", ai_user: ai_user)
        expect(hint).to include("パートナーへのチョコ")
      end

      it "returns single hint for single AI" do
        ai_user.ai_profile.update!(relationship_status: :single)
        hint = described_class.post_hint_for("valentine", ai_user: ai_user)
        expect(hint).to include("義理チョコ")
      end

      it "returns single hint when ai_user is nil" do
        hint = described_class.post_hint_for("valentine", ai_user: nil)
        expect(hint).to include("義理チョコ")
      end
    end

    context "with a relationship-branching hint (christmas_eve)" do
      let(:ai_user) { create(:ai_user) }

      it "returns coupled hint for coupled AI" do
        ai_user.ai_profile.update!(relationship_status: :in_relationship)
        hint = described_class.post_hint_for("christmas_eve", ai_user: ai_user)
        expect(hint).to include("パートナーとのクリスマス")
      end

      it "returns single hint for single AI" do
        ai_user.ai_profile.update!(relationship_status: :single)
        hint = described_class.post_hint_for("christmas_eve", ai_user: ai_user)
        expect(hint).to include("友人とのクリスマス")
      end
    end

    it "returns nil for unknown event keys" do
      expect(described_class.post_hint_for("unknown_event")).to be_nil
    end
  end

  describe ".theme_for" do
    it "returns theme for events that have one" do
      expect(described_class.theme_for("cherry_blossom")).to eq("new_hobby")
      expect(described_class.theme_for("halloween")).to eq("new_hobby")
      expect(described_class.theme_for("new_season")).to eq("skill_up")
      expect(described_class.theme_for("new_year")).to eq("new_hobby")
    end

    it "returns nil for events with no theme" do
      expect(described_class.theme_for("setsubun")).to be_nil
      expect(described_class.theme_for("tanabata")).to be_nil
      expect(described_class.theme_for("obon")).to be_nil
    end

    context "for valentine" do
      let(:ai_user) { create(:ai_user) }

      it "returns new_relationship for coupled AI" do
        ai_user.ai_profile.update!(relationship_status: :in_relationship)
        expect(described_class.theme_for("valentine", ai_user: ai_user)).to eq("new_relationship")
      end

      it "returns nil for single AI" do
        ai_user.ai_profile.update!(relationship_status: :single)
        expect(described_class.theme_for("valentine", ai_user: ai_user)).to be_nil
      end

      it "returns nil when ai_user is nil" do
        expect(described_class.theme_for("valentine", ai_user: nil)).to be_nil
      end
    end

    context "for christmas_eve" do
      let(:ai_user) { create(:ai_user) }

      it "returns new_relationship for coupled AI" do
        ai_user.ai_profile.update!(relationship_status: :married)
        expect(described_class.theme_for("christmas_eve", ai_user: ai_user)).to eq("new_relationship")
      end

      it "returns nil for single AI" do
        ai_user.ai_profile.update!(relationship_status: :single)
        expect(described_class.theme_for("christmas_eve", ai_user: ai_user)).to be_nil
      end
    end
  end

  describe ".enriched_events_for" do
    let(:ai_user) { create(:ai_user) }

    it "returns enriched data for known event keys" do
      result = described_class.enriched_events_for(%w[cherry_blossom tanabata], ai_user: ai_user)
      expect(result.size).to eq(2)
      expect(result.first[:key]).to eq("cherry_blossom")
      expect(result.first[:label]).to eq("お花見シーズン")
      expect(result.first[:hint]).to include("お花見")
    end

    it "skips unknown event keys" do
      result = described_class.enriched_events_for(%w[cherry_blossom unknown_xyz])
      keys = result.map { |r| r[:key] }
      expect(keys).to include("cherry_blossom")
      expect(keys).not_to include("unknown_xyz")
    end

    it "returns empty array for empty event list" do
      expect(described_class.enriched_events_for([])).to eq([])
    end

    it "personalizes valentine hint based on relationship status" do
      ai_user.ai_profile.update!(relationship_status: :in_relationship)
      result = described_class.enriched_events_for(%w[valentine], ai_user: ai_user)
      expect(result.first[:hint]).to include("パートナーへのチョコ")
    end
  end
end
