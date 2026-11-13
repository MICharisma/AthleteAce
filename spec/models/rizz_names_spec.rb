require "rails_helper"

RSpec.describe "Rizz name consumption", type: :model do
  let(:player) { create(:player, first_name: "Josh", last_name: "Hart") }
  let(:figure) { player.figure }

  before { allow(RizzNames).to receive(:enabled?).and_return(true) }

  def referring_name(**attributes)
    RizzName.create!(figure: figure, purpose: "referring", display_name: "Joshua Hart", **attributes)
  end

  it "uses source names until a projection exists and when the integration is disabled" do
    expect(player.display_name).to eq("Josh Hart")
    expect(GameNames.playable(Player.all)).to include(player)
    referring_name
    allow(RizzNames).to receive(:enabled?).and_return(false)

    expect(player.reload.display_name).to eq("Josh Hart")
    expect(Figure.matching_name("Josh Hart")).to include(figure)
  end

  it "displays and searches authorized names without overwriting source fields" do
    referring_name(search_forms: [{ "exact_text" => "J. Hart" }])

    expect(player.reload.display_name).to eq("Joshua Hart")
    expect(player.name).to eq("Josh Hart")
    expect(Figure.matching_name("J. Hart")).to include(figure)
    expect(Figure.matching_name("Joshua Hart")).to include(figure)
    expect(Figure.matching_name("Josh Hart")).not_to include(figure)
  end

  it "keeps short and referring purposes independent" do
    referring_name
    RizzName.create!(figure: figure, purpose: "short", display_name: "Hart")

    expect(figure.reload.display_name).to eq("Joshua Hart")
    expect(figure.display_name(purpose: "short")).to eq("Hart")
  end

  it "withholds invalidated names from search and playable scopes" do
    row = referring_name(state: "invalidated")

    expect(player.reload.display_name).to eq("Player")
    expect(player.name_withheld?).to be(true)
    expect(Figure.matching_name("Hart")).not_to include(figure)
    expect(GameNames.playable(Player.all)).not_to include(player)
    row.update!(state: "current", display_name: nil)
    expect(player.reload.name_withheld?).to be(true)
  end

  it "uses projected names for new rounds and omits withheld players" do
    referring_name
    rival_team = create(:team, league: player.league)
    create(:player, team: rival_team)
    withheld = create(:player, team: player.team)
    RizzName.create!(figure: withheld.figure, purpose: "referring", display_name: nil)
    setup = GameRoundSetup.new(team_id: player.team_id)

    expect(setup.subjects).to contain_exactly(player)
    round = setup.start!(create(:ace))
    expect(round.questions.map { |question| question.fetch("subject_name") }.uniq).to eq(["Joshua Hart"])
  end

  it "refreshes names on reused questions and drops newly withheld subjects" do
    row = referring_name
    question = { subject_type: "Player", subject_id: player.id, subject_name: "Josh Hart", target_type: "Team",
      target_id: player.team_id, target_name: player.team.name, choices: [] }

    expect(GameNames.refresh([question]).sole.fetch("subject_name")).to eq("Joshua Hart")
    row.update!(display_name: nil)
    expect(GameNames.refresh([question])).to be_empty
  end
end
