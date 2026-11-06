# Sends a Person's names to Rizz and takes up the code Rizz assigns. Seeding
# never calls Rizz; this runs as its own step (rake rizz:sync_people).
#
# Each Person's snapshot gets a revision from its contents, so an unchanged
# person is skipped and a retry of the same snapshot is idempotent. When Rizz
# places the person in an entity, the person adopts its MIC-RZZ code and keeps
# its provisional code as an alias. When Rizz holds the person for an identity
# review, the sync records the review; syncing again after the decision
# completes it. When Rizz places two local people in one entity, the second is
# left for a local merge rather than given a code another person holds.
#
# Needs the rizz-client gem, RIZZ_ENDPOINT and RIZZ_API_TOKEN.
class RizzPersonSync
  def self.client
    require "rizz-client"
    Rizz::Client.new(endpoint: ENV.fetch("RIZZ_ENDPOINT"), token: ENV.fetch("RIZZ_API_TOKEN"))
  end

  # People with at least one athletic profile, which is what Rizz imports.
  def self.people
    Person.where(id: Player.unscoped.select(:person_id)).includes(:players, :rizz_sync)
  end

  def initialize(client: self.class.client)
    @client = client
  end

  def call(person)
    sync = person.rizz_sync || person.build_rizz_sync
    record = Rizz::AthleteAce::PersonRecord.new(person)
    evidence = evidence_for(person)
    revision = Digest::SHA256.hexdigest(JSON.generate(record.to_h(source_revision: "", identity_evidence: evidence).sort.to_h))
    return sync if sync.persisted? && sync.state == "synced" && sync.source_revision == revision

    attempt(sync, person, record, evidence, revision)
  rescue ArgumentError => error
    sync.update!(state: "skipped", last_error: error.message.truncate(255))
    sync
  rescue Rizz::Unavailable, Rizz::Error => error
    sync.update!(state: "failed", source_revision: revision, last_error: "#{error.class}: #{error.message}".truncate(255))
    sync
  end

  private

  attr_reader :client

  def attempt(sync, person, record, evidence, revision, retried: false)
    expected_version = sync.rizz_version if sync.rizz_entity_id
    payload = record.to_h(source_revision: revision, identity_evidence: evidence, expected_version: expected_version)
    result = client.import_athleteace_person(payload, idempotency_key: "person-#{person.id}-#{revision}")
    return hold_for_review(sync, result, revision) if result["status"] == "review_required"

    place(sync, person, result, revision)
  rescue Rizz::Error => error
    # Another source record may have changed the entity since the last sync.
    raise unless error.status == 409 && sync.rizz_entity_id && !retried
    sync.rizz_version = client.entity(sync.rizz_entity_id).fetch("version")
    attempt(sync, person, record, evidence, revision, retried: true)
  end

  def hold_for_review(sync, result, revision)
    sync.update!(state: "review", review_id: result.fetch("review_id"), source_revision: revision, last_error: nil)
    sync
  end

  def place(sync, person, result, revision)
    code = result.fetch("qualified_code")
    holder = Person.where(entity_code: code).where.not(id: person.id).first ||
      RizzSync.where(rizz_entity_id: result.fetch("entity_id")).where.not(person_id: person.id).first&.person
    sync.assign_attributes(rizz_entity_id: result.fetch("entity_id"), rizz_version: result.fetch("version"), rizz_code: code,
      source_revision: revision, review_id: nil, synced_at: Time.current)
    if holder
      sync.update!(state: "merge_needed", last_error: "Rizz places this person in #{code}, which Person #{holder.id} holds")
    else
      Person.transaction do
        person.adopt_rizz_code!(code)
        sync.update!(state: "synced", last_error: nil)
      end
    end
    sync
  end

  # Stable across adoption (it leaves out the person's own code), so it
  # doesn't change the snapshot revision once the person takes its Rizz code.
  def evidence_for(person)
    profiles = person.players.map { |player| player.entity_code.presence || "Player #{player.id}" }.sort
    source = person.source["url"].presence if person.source.is_a?(Hash)
    ["AthleteAce Person #{person.id} holds #{profiles.join(', ')}", ("source #{source}" if source)].compact.join("; ").truncate(512)
  end
end
