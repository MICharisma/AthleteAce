class ShotUpload
  class Invalid < StandardError; end
  class Conflict < StandardError; end

  MAX_BYTES = 25.megabytes

  def initialize(token:, key:, image:, metadata:)
    @token, @key, @image = token, key, image
    raise Invalid, "Supply an Idempotency-Key of 1–128 printable ASCII characters." unless key.match?(/\A[!-~]{1,128}\z/)
    unless image.is_a?(ActionDispatch::Http::UploadedFile) && image.size.between?(1, MAX_BYTES)
      raise Invalid, "Supply an image file up to 25 MB."
    end

    @content_type = Marcel::MimeType.for(image.tempfile)
    raise Invalid, "Unsupported image type." unless Shot::IMAGE_TYPES.include?(@content_type)

    parse_metadata(metadata)
    @fingerprint = Digest::SHA256.hexdigest([
      Digest::SHA256.file(image.path).hexdigest, image.original_filename, @tags, @captures
    ].to_json)
  end

  def call
    Shot.transaction do
      # Serialize retries of this key while allowing other uploads to proceed.
      lock_id = Digest::SHA256.digest("#{@token.id}:#{@key}").unpack1("q>")
      Shot.connection.execute("SELECT pg_advisory_xact_lock(#{lock_id})")
      existing = Shot.find_by(shot_upload_token: @token, upload_key: @key)
      if existing
        raise Conflict, "This Idempotency-Key was used with a different payload." unless existing.upload_fingerprint == @fingerprint
        next [existing, false]
      end

      captures = resolve_captures
      @blob = ActiveStorage::Blob.build_after_unfurling(io: @image.tempfile, filename: @image.original_filename,
        content_type: @content_type, identify: false)
      @blob.save!
      @blob.upload_without_unfurling(@image.tempfile)
      shot = Shot.create!(image: @blob, tags: @tags, shot_upload_token: @token,
        upload_key: @key, upload_fingerprint: @fingerprint)
      captures.each { |player, weight| shot.captures.create!(player: player, weight: weight) }
      [shot, true]
    end
  rescue StandardError
    @blob&.delete unless @blob&.persisted? && ActiveStorage::Blob.exists?(@blob.id)
    raise
  end

  private

  def parse_metadata(metadata)
    raise Invalid, "Metadata must be a JSON object." unless metadata.is_a?(String) && metadata.bytesize <= 32.kilobytes

    metadata = JSON.parse(metadata)
    unless metadata.is_a?(Hash) && (metadata.keys - %w[tags captures]).empty?
      raise Invalid, "Metadata accepts tags and captures."
    end

    tags = metadata.fetch("tags", [])
    unless tags.is_a?(Array) && tags.size <= 30 && tags.all? { |tag| tag.is_a?(String) && tag.length <= 80 && !tag.include?("\0") }
      raise Invalid, "Supply up to 30 text tags of up to 80 characters each."
    end
    @tags = tags.map { |tag| tag.strip.downcase }.compact_blank.uniq.sort

    captures = metadata.fetch("captures", [])
    raise Invalid, "Supply an array of up to 50 captures." unless captures.is_a?(Array) && captures.size <= 50

    @captures = captures.map do |capture|
      unless capture.is_a?(Hash) && (capture.keys - %w[player_entity_code weight]).empty?
        raise Invalid, "Each capture accepts player_entity_code and weight."
      end

      code = capture["player_entity_code"]
      weight = capture.fetch("weight", 1)
      unless code.is_a?(String) && code.length <= 160 && code.match?(/\A[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)*\z/)
        raise Invalid, "Each capture requires a player entity code."
      end
      unless weight.is_a?(Integer) && weight.between?(0, 2_147_483_647)
        raise Invalid, "Capture weights must be integers between 0 and 2,147,483,647."
      end
      [code.delete_prefix("MIC-ALA-"), weight]
    end.sort
  rescue JSON::ParserError
    raise Invalid, "Metadata must be a JSON object."
  end

  def resolve_captures
    captures = @captures.map do |code, weight|
      player = EntityCode.resolve(Player, code) || raise(Invalid, "Unknown player entity code #{code}.")
      [player, weight]
    end
    unless captures.map { |player, _| player.id }.uniq.size == captures.size
      raise Invalid, "A player may appear only once per shot."
    end
    captures
  end
end
