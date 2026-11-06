# Sends a Figure's names to Rizz and takes up the code Rizz assigns. Seeding
# never calls Rizz; this runs as its own step (rake rizz:sync_figures).
#
# Each Figure's snapshot gets a revision from its contents, so an unchanged
# figure is skipped and a retry of the same snapshot is idempotent. When Rizz
# places the figure in an entity, the figure adopts its MIC-RZZ code and keeps
# its provisional code as an alias. When Rizz holds the figure for an identity
# review, the sync records the review; syncing again after the decision
# completes it. When Rizz places two local figures in one entity, the second is
# left for a local merge rather than given a code another figure holds.
#
# Needs the rizz-client gem, RIZZ_ENDPOINT and RIZZ_API_TOKEN.
class RizzFigureSync
  def self.client
    require "rizz-client"
    Rizz::Client.new(endpoint: ENV.fetch("RIZZ_ENDPOINT"), token: ENV.fetch("RIZZ_API_TOKEN"))
  end

  def self.figures
    Figure.where(id: Player.unscoped.select(:figure_id)).includes(:players, :rizz_sync)
  end

  def initialize(client: self.class.client)
    @client = client
  end

  def call(figure)
    sync = figure.rizz_sync || figure.build_rizz_sync
    # The external SDK keeps its PersonRecord contract until the Rizz update.
    record = Rizz::AthleteAce::PersonRecord.new(figure)
    evidence = evidence_for(figure)
    revision = Digest::SHA256.hexdigest(JSON.generate(record.to_h(source_revision: "", identity_evidence: evidence).sort.to_h))
    return sync if sync.persisted? && sync.state == "synced" && sync.source_revision == revision

    attempt(sync, figure, record, evidence, revision)
  rescue ArgumentError => error
    sync.update!(state: "skipped", last_error: error.message.truncate(255))
    sync
  rescue Rizz::Unavailable, Rizz::Error => error
    sync.update!(state: "failed", source_revision: revision, last_error: "#{error.class}: #{error.message}".truncate(255))
    sync
  end

  private

  attr_reader :client

  def attempt(sync, figure, record, evidence, revision, retried: false)
    expected_version = sync.rizz_version if sync.rizz_entity_id
    payload = record.to_h(source_revision: revision, identity_evidence: evidence, expected_version: expected_version)
    result = client.import_athleteace_person(payload, idempotency_key: "figure-#{figure.id}-#{revision}")
    return hold_for_review(sync, result, revision) if result["status"] == "review_required"

    place(sync, figure, result, revision)
  rescue Rizz::Error => error
    # Another source record may have changed the entity since the last sync.
    raise unless error.status == 409 && sync.rizz_entity_id && !retried
    sync.rizz_version = client.entity(sync.rizz_entity_id).fetch("version")
    attempt(sync, figure, record, evidence, revision, retried: true)
  end

  def hold_for_review(sync, result, revision)
    sync.update!(state: "review", review_id: result.fetch("review_id"), source_revision: revision, last_error: nil)
    sync
  end

  def place(sync, figure, result, revision)
    code = result.fetch("qualified_code")
    holder = Figure.where(entity_code: code).where.not(id: figure.id).first ||
      RizzSync.where(rizz_entity_id: result.fetch("entity_id")).where.not(figure_id: figure.id).first&.figure
    sync.assign_attributes(rizz_entity_id: result.fetch("entity_id"), rizz_version: result.fetch("version"), rizz_code: code,
      source_revision: revision, review_id: nil, synced_at: Time.current)
    if holder
      sync.update!(state: "merge_needed", last_error: "Rizz places this figure in #{code}, which Figure #{holder.id} holds")
    else
      Figure.transaction do
        figure.adopt_rizz_code!(code)
        sync.update!(state: "synced", last_error: nil)
      end
    end
    sync
  end

  def evidence_for(figure)
    profiles = figure.players.map { |player| player.entity_code.presence || "Player #{player.id}" }.sort
    source = figure.source["url"].presence if figure.source.is_a?(Hash)
    ["AthleteAce Figure #{figure.id} holds #{profiles.join(', ')}", ("source #{source}" if source)].compact.join("; ").truncate(512)
  end
end
