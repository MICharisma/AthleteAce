require "rails_helper"

RSpec.describe "Sourced Figure connections", type: :request do
  let(:admin) { create :ace, :admin }
  let(:walk) { create :protocol, name: "Morning walk", routine: "A walk before breakfast" }
  let(:prayer) { create :practice, name: "Prayer" }
  let(:gratitude) { create :practice, name: "Gratitude" }
  let(:exercise) { create :practice, name: "Exercise" }

  def publish(claim, attestation_traits: [ :text ])
    create(:attestation, *attestation_traits, claim: claim) if claim.attestations.empty?
    claim.reload
    FigureClaims::Review.call(claim: claim, actor: admin, action: "publish", revision: claim.moderation_revision,
      status: "pending", digest: claim.review_digest)
    claim.reload
  end

  def practice_tie(figure, protocol, *practices, **attributes)
    tie = create :figure_practice_relationship, figure: figure, protocol: protocol, **attributes
    practices.each { create :practice_connection, figure_practice_relationship: tie, practice: it }
    tie.reload
  end

  it "shows only published claims and their evidence on a Figure page, with honest empty states" do
    figure = create :figure, name: "Jordan Reyes"
    get figure_path(figure)
    expect(response.body).to include("No sourced business connections have been recorded yet.",
      "No sourced practices have been recorded yet.", "No sourced statements have been recorded yet.")
    published = publish(create(:figure_business_relationship, :paid_sponsorship, figure: figure, business: create(:business, name: "Summit Shoes")))
    create :attestation, claim: create(:figure_business_relationship, figure: figure, business: create(:business, name: "Hidden Co")),
      excerpt: "hidden passage"
    get figure_path(figure)
    expect(response.body).to include("Summit Shoes", "Sponsored by", "Paid (documented)")
    expect(response.body).not_to include("Hidden Co", "hidden passage")
    published.update! context: "Changed"
    get figure_path(figure)
    expect(response.body).not_to include("Summit Shoes")
  end

  it "labels predicates, compensation, founder history and time context honestly" do
    figure = create :figure
    business = create :business, name: "Harbor Coffee"
    publish create(:figure_business_relationship, figure: figure, business: business, predicate: "founded", start_date: "2012", temporal_state: "historical")
    publish create(:figure_business_relationship, figure: figure, business: business, predicate: "owns", start_date: "2012", end_date: "2020-06", temporal_state: "historical")
    publish create(:figure_business_relationship, figure: figure, predicate: "promotes", start_date: "2018")
    publish create(:figure_business_relationship, :reported_current, figure: figure, predicate: "invests_in", vehicle_name: "Reyes Holdings")
    publish create(:figure_business_relationship, figure: figure, predicate: "endorses", temporal_state: "planned", start_date: "2027")
    get figure_path(figure)
    expect(response.body).to include("Founded 2012", "Historical · 2012 to 2020-06", "Current status unknown · 2018 to unknown end",
      "Compensation unknown", "Reported current as of 2026-10", "Through Reyes Holdings", "Planned · from 2027")
    expect(response.body).not_to include("Present")
  end

  it "shows one association with every practice it names and keeps another person's interpretation separate" do
    reyes = create :figure, name: "Jordan Reyes"
    okafor = create :figure, name: "Ada Okafor"
    publish practice_tie(reyes, walk, prayer, gratitude, interpretation: "My morning walk is prayer and gratitude.")
    publish practice_tie(okafor, walk, exercise)
    get figure_path(reyes)
    expect(response.body.scan("public_card_for_figure_practice_relationship").size).to eq(1)
    expect(response.body).to include("Gratitude", "Prayer", "My morning walk is prayer and gratitude.")
    expect(response.body).not_to include("Exercise")

    get practice_path(prayer)
    expect(response.body).to include("Jordan Reyes", "Morning walk")
    expect(response.body).not_to include("Ada Okafor")

    get protocol_path(walk)
    expect(response.body).to include("Jordan Reyes", "Ada Okafor", "Exercise", "A walk before breakfast")
  end

  it "deduplicates people and associations under combined practice filters" do
    reyes = create :figure, name: "Jordan Reyes"
    publish practice_tie(reyes, walk, prayer, gratitude)
    publish practice_tie(reyes, create(:protocol, name: "Box breathing"), create(:practice, name: "Meditation"))
    publish practice_tie(create(:figure, name: "Ada Okafor"), walk, exercise, predicate: "recommends")
    get practices_path(practice_ids: [ prayer.id, gratitude.id ])
    expect(response.body.scan("connections_for_figure_").size).to eq(1)
    expect(response.body.scan("public_card_for_figure_practice_relationship").size).to eq(1)
    expect(response.body).to include("1 person")
    get practices_path(protocol_id: walk.id, predicate: "recommends")
    expect(response.body).to include("Ada Okafor")
    expect(response.body).not_to include("Jordan Reyes")
    get practices_path(predicate: "teaches")
    expect(response.body).to include("No published practice connections match these filters.")
  end

  it "shows general-only and protocol-only associations" do
    figure = create :figure
    publish practice_tie(figure, nil, prayer)
    publish practice_tie(figure, walk)
    get figure_path(figure)
    expect(response.body).to include("General practice", "No practice interpretation recorded.")
  end

  it "attributes statements by kind and speaker, preserving Unicode and qualifiers" do
    figure = create :figure, name: "Zoë Laurent"
    topic = create :topic, name: "Discipline"
    publish create(:attributed_statement, figure: figure, topic: topic, text: "La discipline, c'est la liberté — mostly.", statement_date: "2019-05")
    publish create(:attributed_statement, :observer_characterization, figure: figure, observer_name: "Her first coach", text: "Always early.")
    publish create(:attributed_statement, figure: figure, attribution_kind: "attributed_paraphrase", text: "Rest is part of training.")
    get figure_path(figure)
    body = CGI.unescapeHTML(response.body)
    expect(body).to include("Direct quote", "“La discipline, c'est la liberté — mostly.”", "Observer characterization",
      "Said about Zoë Laurent by Her first coach", "Paraphrase of Zoë Laurent, not their exact words", "2019-05")
    get topic_path(topic)
    expect(response.body).to include(figure_path(figure))
  end

  it "labels each attestation by its actual creator, form and source, without the entering ace" do
    figure = create :figure, name: "Jordan Reyes"
    tie = create :figure_business_relationship, figure: figure
    create :attestation, :video, claim: tie, author: figure, entered_by: create(:ace, display_name: "Entering Ace"), locator: "04:12-04:40"
    create :attestation, claim: tie, author_name: "Dana Ortiz", publisher: "Example Sports Daily", published_on: nil
    create :attestation, claim: tie, content_form: "image", url: nil, media_url: "https://example.com/photo.jpg", excerpt: "At the launch"
    create :attestation, :text, claim: tie, body: "Proud to partner with them."
    publish tie
    get figure_path(figure)
    expect(response.body).to include("Video · By", "Segment: 04:12-04:40", "By Dana Ortiz", "Example Sports Daily",
      "Publication date unknown", 'src="https://example.com/photo.jpg"', 'alt="At the launch"', "Proud to partner with them.", "4 sources")
    expect(response.body).not_to include("Entering Ace")
  end

  it "lists businesses with deduplicated people, predicate and period filters, and pagination" do
    business = create :business, name: "Summit Shoes"
    people = create_list(:figure, FigureConnectionBrowsing::PEOPLE_PER_PAGE + 1)
    people.each { publish create(:figure_business_relationship, figure: it, business: business, predicate: "promotes") }
    publish create(:figure_business_relationship, figure: people.first, business: business, predicate: "owns", start_date: "2001", end_date: "2005", temporal_state: "historical")
    create :figure_business_relationship, business: create(:business, name: "Pending Only Co")
    get businesses_path
    expect(response.body).to include("Summit Shoes", "#{people.size} people")
    expect(response.body).not_to include("Pending Only Co")
    get business_path(business)
    expect(response.body).to include("#{people.size} people")
    expect(response.body.scan("connections_for_figure_").size).to eq(FigureConnectionBrowsing::PEOPLE_PER_PAGE)
    get business_path(business, page: 2)
    expect(response.body.scan("connections_for_figure_").size).to eq(1)
    get business_path(business, predicate: "owns", period: "historical")
    expect(response.body).to include("1 person", "Historical · 2001 to 2005")
    get business_path(business, predicate: "founded")
    expect(response.body).to include("No published connections match these filters.")
  end

  it "previews published content on a Player page and links Browse" do
    player = create :player
    publish create(:attributed_statement, figure: player.figure)
    create :figure_business_relationship, figure: player.figure
    get player_path(player)
    expect(response.body).to include("1 statement", figure_path(player.figure, anchor: "values"))
    expect(response.body).not_to include("business connection")
    get browse_path
    expect(response.body).to include(businesses_path, practices_path, protocols_path, topics_path)
  end

  it "gives a coach without a player profile the same sections" do
    tenure = create :staff_tenure, title: "Head coach"
    publish create(:attributed_statement, figure: tenure.figure, staff_tenure: tenure, text: "Teach the why.")
    get figure_path(tenure.figure)
    expect(response.body).to include("Teach the why.", "as Head coach")
  end
end
