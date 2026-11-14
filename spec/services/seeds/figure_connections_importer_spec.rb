require "rails_helper"
require "tmpdir"

RSpec.describe "Figure connection seed imports" do
  def import_records(records)
    Dir.mktmpdir("figure-connections") do |directory|
      path = File.join(directory, "connections.yaml")
      File.write(path, YAML.dump({ "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }))
      Seeds::LibraryImporter.new.call([ path ])
    end
  end

  def definition(type, code, attributes, references = {})
    { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
  end

  let(:records) do
    [
      definition("Attestation", "ATTESTATION-REYES-WALK-VIDEO",
        { "content_form" => "video", "url" => "https://example.com/videos/reyes-mornings", "locator" => "02:10-02:45",
          "author_name" => "Jordan Reyes", "publisher" => "Example Sports Daily", "published_on" => "2025-03",
          "context" => "Reyes describes the walk as both prayer and gratitude." },
        { "claim" => "PRACTICE_TIE-REYES-MORNING_WALK", "author" => "FIGURE-REYES_JORDAN" }),
      definition("PracticeConnection", "PRACTICE_CONNECTION-REYES-WALK-PRAYER", {},
        { "figure_practice_relationship" => "PRACTICE_TIE-REYES-MORNING_WALK", "practice" => "PRACTICE-PRAYER" }),
      definition("PracticeConnection", "PRACTICE_CONNECTION-REYES-WALK-GRATITUDE", {},
        { "figure_practice_relationship" => "PRACTICE_TIE-REYES-MORNING_WALK", "practice" => "PRACTICE-GRATITUDE" }),
      definition("FigurePracticeRelationship", "PRACTICE_TIE-REYES-MORNING_WALK",
        { "predicate" => "participates_in", "interpretation" => "My morning walk is prayer and gratitude.", "start_date" => "2025" },
        { "figure" => "FIGURE-REYES_JORDAN", "protocol" => "PROTOCOL-MORNING_WALK" }),
      definition("Practice", "PRACTICE-PRAYER", { "name" => "Prayer" }),
      definition("Practice", "PRACTICE-GRATITUDE", { "name" => "Gratitude" }),
      definition("Protocol", "PROTOCOL-MORNING_WALK", { "name" => "Morning walk" }),
      definition("Figure", "FIGURE-REYES_JORDAN", { "name" => "Jordan Reyes" }),
      definition("Business", "BUSINESS-HARBOR_COFFEE", { "name" => "Harbor Coffee", "founded_year" => 2019,
        "source" => { "url" => "https://example.com/harbor-coffee/about" } }),
      definition("FigureBusinessRelationship", "BUSINESS_TIE-REYES-HARBOR_COFFEE-INVESTS",
        { "predicate" => "invests_in", "vehicle_name" => "Reyes Holdings", "start_date" => "2021" },
        { "figure" => "FIGURE-REYES_JORDAN", "business" => "BUSINESS-HARBOR_COFFEE" }),
      definition("Attestation", "ATTESTATION-REYES-HARBOR-PORTFOLIO",
        { "content_form" => "link", "url" => "https://example.com/reyes-holdings/portfolio",
          "excerpt" => "Harbor Coffee (2021)", "context" => "The holding company lists Harbor Coffee." },
        { "claim" => "BUSINESS_TIE-REYES-HARBOR_COFFEE-INVESTS" }),
      definition("Topic", "TOPIC-GRATITUDE", { "name" => "Gratitude" }),
      definition("AttributedStatement", "STATEMENT-REYES-GRATITUDE-2025",
        { "attribution_kind" => "direct_quote", "text" => "Every step is a thank-you.", "statement_date" => "2025-03" },
        { "figure" => "FIGURE-REYES_JORDAN", "topic" => "TOPIC-GRATITUDE",
          "figure_practice_relationship" => "PRACTICE_TIE-REYES-MORNING_WALK" })
    ]
  end

  it "imports every connection type in dependency order and replays as a no-op" do
    report = import_records(records)
    expect(report[:conflicts]).to be_empty
    relationship = FigurePracticeRelationship.sole
    expect(relationship.practices.map(&:name)).to eq(%w[Gratitude Prayer])
    expect(relationship.attestations.sole).to have_attributes(content_form: "video", author: Figure.sole, published_on: "2025-03")
    expect(FigureBusinessRelationship.sole).to have_attributes(predicate: "invests_in", vehicle_name: "Reyes Holdings")
    expect(Business.sole.source).to eq("url" => "https://example.com/harbor-coffee/about")
    expect(AttributedStatement.sole.figure_practice_relationship).to eq(relationship)

    counts = [ PracticeConnection, Attestation, FigurePracticeRelationship, AttributedStatement ].map(&:count)
    replay = import_records(records.reverse)
    expect(replay[:created]).to be_empty
    expect(replay[:conflicts]).to be_empty
    expect([ PracticeConnection, Attestation, FigurePracticeRelationship, AttributedStatement ].map(&:count)).to eq(counts)
  end

  it "reports changed evidence as a conflict instead of overwriting it" do
    import_records(records)
    records.first["attributes"]["locator"] = "03:00-03:30"
    report = import_records(records)
    expect(report[:conflicts].sole).to include(code: "ATTESTATION-REYES-WALK-VIDEO")
    expect(Attestation.find_by!(entity_code: "ATTESTATION-REYES-WALK-VIDEO").locator).to eq("02:10-02:45")
  end

  it "rejects an attestation for an unsupported claim type" do
    bad = definition("Attestation", "ATTESTATION-BAD", { "content_form" => "text", "body" => "x" }, { "claim" => "TOPIC-GRATITUDE" })
    expect { import_records([ records[11], bad ]) }.to raise_error(Seeds::LibraryImporter::Error, /invalid for Attestation.claim/)
  end
end
