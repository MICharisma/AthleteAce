require "rails_helper"

RSpec.describe RizzFigureSync do
  let(:client) { double("Rizz client") }
  let(:service) { described_class.new(client: client) }
  let(:figure) { create(:player, first_name: "Mark", last_name: "Scheifele", entity_code: "PLAYER-SCHEIFELE_MARK").figure }
  let(:record) { double("Rizz person record") }
  let(:entity_id) { SecureRandom.uuid }
  let(:code) { "MIC-RZZ-SCHE_MARK_7KM3" }
  let(:placement) { { "entity_id" => entity_id, "version" => 1, "qualified_code" => code } }

  before do
    stub_const("Rizz::Error", Class.new(StandardError) { attr_accessor :status })
    stub_const("Rizz::Unavailable", Class.new(Rizz::Error))
    stub_const("Rizz::AthleteAce::PersonRecord", Struct.new(:figure))
    allow(Rizz::AthleteAce::PersonRecord).to receive(:new).with(figure).and_return(record)
    allow(record).to receive(:to_h) { |**options| { "name" => figure.name }.merge(options.stringify_keys) }
  end

  it "selects each figure with an athletic profile once and excludes staff-only figures" do
    create :player, figure: figure
    create :figure, name: "María Calderón"

    expect(described_class.figures).to contain_exactly(figure)
  end

  it "sends the figure through the existing SDK and adopts its code with Figure aliases" do
    original_code = figure.entity_code
    expect(client).to receive(:import_athleteace_person) do |payload, idempotency_key:|
      expect(payload.fetch("name")).to eq("Mark Scheifele")
      expect(payload.fetch("identity_evidence")).to include("AthleteAce Figure #{figure.id}", "PLAYER-SCHEIFELE_MARK")
      expect(payload.fetch("expected_version")).to be_nil
      expect(idempotency_key).to eq("figure-#{figure.id}-#{payload.fetch('source_revision')}")
      placement
    end

    sync = service.call(figure)

    expect(sync).to have_attributes(figure: figure, state: "synced", rizz_entity_id: entity_id, rizz_version: 1, rizz_code: code)
    expect(figure.reload.entity_code).to eq(code)
    expect(EntityCode.resolve(Figure, original_code)).to eq(figure)
    expect(EntityCode.where(record: figure).pluck(:record_type).uniq).to eq([ "Figure" ])
  end

  it "skips an unchanged synced snapshot and sends a changed name" do
    expect(client).to receive(:import_athleteace_person).twice.and_return(placement)

    sync = service.call(figure)
    revision = sync.source_revision
    expect(service.call(figure).source_revision).to eq(revision)
    figure.update! first_name: "Marcus"
    expect(service.call(figure).source_revision).not_to eq(revision)
  end

  it "records an identity review and completes it on a later sync" do
    original_code = figure.entity_code
    review_id = SecureRandom.uuid
    expect(client).to receive(:import_athleteace_person).and_return({ "status" => "review_required", "review_id" => review_id }, placement)

    expect(service.call(figure)).to have_attributes(state: "review", review_id: review_id)
    expect(figure.reload.entity_code).to eq(original_code)
    expect(service.call(figure)).to have_attributes(state: "synced", review_id: nil)
  end

  it "records a needed merge when another figure already holds the Rizz entity" do
    holder = create :figure, entity_code: code
    expect(client).to receive(:import_athleteace_person).and_return(placement)

    expect(service.call(figure)).to have_attributes(state: "merge_needed", rizz_entity_id: entity_id)
    expect(figure.reload.entity_code).not_to eq(code)
    expect(holder.reload.entity_code).to eq(code)
  end

  it "also detects another figure holding the Rizz entity through its sync" do
    holder = create :figure
    holder.create_rizz_sync! state: "synced", rizz_entity_id: entity_id
    expect(client).to receive(:import_athleteace_person).and_return(placement)

    expect(service.call(figure)).to have_attributes(state: "merge_needed")
    expect(figure.reload.entity_code).not_to eq(code)
  end

  it "refreshes a conflicting version once and retries the same snapshot" do
    figure.create_rizz_sync! state: "failed", rizz_entity_id: entity_id, rizz_version: 1
    conflict = Rizz::Error.new("Version conflict")
    conflict.status = 409
    first_key = nil
    expect(client).to receive(:import_athleteace_person).ordered do |payload, idempotency_key:|
      expect(payload.fetch("expected_version")).to eq(1)
      first_key = idempotency_key
      raise conflict
    end
    expect(client).to receive(:entity).with(entity_id).ordered.and_return({ "version" => 2 })
    expect(client).to receive(:import_athleteace_person).ordered do |payload, idempotency_key:|
      expect(payload.fetch("expected_version")).to eq(2)
      expect(idempotency_key).to eq(first_key)
      placement.merge("version" => 3)
    end

    expect(service.call(figure)).to have_attributes(state: "synced", rizz_version: 3)
  end

  it "records an unavailable service without changing the figure's code" do
    original_code = figure.entity_code
    expect(client).to receive(:import_athleteace_person).and_raise(Rizz::Unavailable, "Offline")

    expect(service.call(figure)).to have_attributes(state: "failed", last_error: "Rizz::Unavailable: Offline")
    expect(figure.reload.entity_code).to eq(original_code)
  end

  it "records a skipped snapshot when the SDK rejects it" do
    allow(Rizz::AthleteAce::PersonRecord).to receive(:new).with(figure).and_raise(ArgumentError, "No athletic profile")
    expect(client).not_to receive(:import_athleteace_person)

    expect(service.call(figure)).to have_attributes(state: "skipped", last_error: "No athletic profile")
  end
end
