require "rails_helper"

RSpec.describe TeamsHelper, type: :helper do
  let(:basketball) { create(:sport, name: "Basketball") }
  let(:soccer) { create(:sport, name: "Soccer") }
  let(:mens_hoops) { create(:league, sport: basketball, name: "NCAA Division I Men's Basketball", abbreviation: "NCAA D1 Men") }
  let(:womens_hoops) { create(:league, sport: basketball, name: "NCAA Division I Women's Basketball", abbreviation: "NCAA D1 Women") }
  let(:epl) { create(:league, sport: soccer, name: "Premier League", abbreviation: "EPL") }
  let(:championship) { create(:league, sport: soccer, name: "EFL Championship", abbreviation: "EFL_CHAMPIONSHIP") }

  describe "League#short_name and League#context_label" do
    it "formats full and short labels without duplicating sport names" do
      expect(mens_hoops.short_name).to eq("NCAA D1 Men")
      expect(mens_hoops.context_label(style: :full)).to eq("NCAA Division I Men's Basketball")
      expect(mens_hoops.context_label(style: :short)).to eq("NCAA D1 Men · Basketball")
      expect(mens_hoops.context_label(style: :short, include_sport: false)).to eq("NCAA D1 Men")

      expect(epl.context_label(style: :full)).to eq("Premier League · Soccer")
      expect(epl.context_label(style: :short)).to eq("EPL · Soccer")

      expect(championship.short_name).to eq("EFL Championship")
      expect(championship.context_label(style: :short)).to eq("EFL Championship · Soccer")

      orphan = League.new(name: "Independent", abbreviation: nil)
      expect(orphan.context_label).to eq("Independent")
      expect(League.new(sport: basketball).context_label).to eq("Basketball")
    end
  end

  describe "Team disambiguation and context methods" do
    let!(:yale_men) { create(:team, league: mens_hoops, territory: "Yale", mascot: "Bulldogs") }
    let!(:yale_women) { create(:team, league: womens_hoops, territory: "Yale", mascot: "Bulldogs") }
    let!(:arsenal) { create(:team, league: epl, territory: nil, mascot: "Arsenal") }
    let!(:whitespace_club_a) { create(:team, league: epl, territory: nil, mascot: "Real  Madrid") }
    let!(:whitespace_club_b) { create(:team, league: championship, territory: " Real", mascot: "Madrid ") }

    it "detects colliding team names consistently in SQL relations and Ruby enumerables" do
      expect(Team.normalized_name("  Yale   Bulldogs ")).to eq("yale bulldogs")
      expect(Team.ambiguous_names).to contain_exactly("yale bulldogs", "real madrid")
      expect(Team.ambiguous_names([ yale_men, yale_women, arsenal ])).to contain_exactly("yale bulldogs")
      expect(Team.ambiguous_names(Team.order(:mascot))).to contain_exactly("yale bulldogs", "real madrid")

      expect(yale_men.name_ambiguous?).to be(true)
      expect(arsenal.name_ambiguous?).to be(false)
      expect(whitespace_club_a.name_ambiguous?).to be(true)
      expect(yale_men.name_ambiguous?(Set.new)).to be(false)
    end

    it "builds full, short, and disambiguated names" do
      expect(yale_men.league_sport_label(style: :short)).to eq("NCAA D1 Men · Basketball")
      expect(yale_men.name_with_context(style: :short)).to eq("Yale Bulldogs · NCAA D1 Men · Basketball")
      expect(yale_men.disambiguated_name(style: :short)).to eq("Yale Bulldogs · NCAA D1 Men · Basketball")
      expect(arsenal.disambiguated_name(style: :short)).to eq("Arsenal")
      expect(arsenal.disambiguated_name(always: true, style: :short)).to eq("Arsenal · EPL · Soccer")
    end
  end

  describe "#team_context_label, #team_display_name, and #team_name_with_context" do
    let!(:yale_men) { create(:team, league: mens_hoops, territory: "Yale", mascot: "Bulldogs") }
    let!(:yale_women) { create(:team, league: womens_hoops, territory: "Yale", mascot: "Bulldogs") }
    let!(:arsenal) { create(:team, league: epl, territory: nil, mascot: "Arsenal") }

    it "formats auto, always, never, nil, and invalid modes" do
      expect(helper.team_context_label(nil)).to be_nil
      expect(helper.team_display_name(nil)).to eq("")
      expect(helper.team_name_with_context(nil)).to eq("")

      expect(helper.team_display_name(yale_men, context: :auto, style: :short)).to eq("Yale Bulldogs · NCAA D1 Men · Basketball")
      expect(helper.team_display_name(yale_men, context: :auto, ambiguous_names: Set.new)).to eq("Yale Bulldogs")
      expect(helper.team_display_name(yale_men, context: :never)).to eq("Yale Bulldogs")
      expect(helper.team_display_name(arsenal, context: :auto)).to eq("Arsenal")
      expect(helper.team_display_name(arsenal, context: :always, style: :short)).to eq("Arsenal · EPL · Soccer")

      expect { helper.team_display_name(arsenal, context: :bogus) }.to raise_error(ArgumentError, /Unknown team context mode/)
    end

    it "renders stacked or separated markup safely" do
      stacked = Nokogiri::HTML.fragment(helper.team_name_with_context(yale_men, style: :short, context_class: "sublabel"))
      expect(stacked.css("span span").map(&:text)).to eq([ "Yale Bulldogs", "NCAA D1 Men · Basketball" ])
      expect(stacked.at_css(".sublabel").text).to eq("NCAA D1 Men · Basketball")

      inline = Nokogiri::HTML.fragment(helper.team_name_with_context(arsenal, context: :always, style: :short, separator: " — ", context_class: "meta"))
      expect(inline.css("span span").map(&:text)).to eq([ "Arsenal", " — ", "EPL · Soccer" ])

      escaped_team = build(:team, league: mens_hoops, territory: "<script>alert(1)</script>", mascot: "Tigers")
      rendered = helper.team_name_with_context(escaped_team, context: :always, style: :short)
      expect(rendered).not_to include("<script>")
      expect(rendered).to include("&lt;script&gt;")
    end
  end
end
