class AssetRepresentation < ApplicationRecord
  class IntegrityError < StandardError; end

  include SeedObservation
  belongs_to :subject, polymorphic: true
  has_one_attached :file
  validates :subject_type, inclusion: { in: %w[Logo Uniform UniformPiece Figure] }
  validates :file_format, :view, :canonical_path, :content_type, presence: true
  validates :view, uniqueness: { scope: [ :subject_type, :subject_id, :file_format ] }
  validates :sha256, format: { with: /\A[a-f0-9]{64}\z/ }
  validates :byte_size, numericality: { only_integer: true, greater_than: 0 }
  validate :relative_media_path
  validate :github_location

  def ingest_file!
    with_lock do
      if file.attached?
        verify_file!
        return :unchanged
      end

      download_file do |download|
        verify_download! download.path
        file.attach ActiveStorage::Blob.create_and_upload!(io: download, filename: File.basename(canonical_path),
          content_type: content_type, identify: false)
      end
    end
    :imported
  end

  def verify_file!
    raise IntegrityError, "Missing stored file for #{entity_code}" unless file.attached?
    file.open { |download| verify_download! download.path }
  end

  def github_url
    github = source.fetch "github"
    path = URI::DEFAULT_PARSER.escape github.fetch("path"), /[^A-Za-z0-9\-._~\/]/
    "https://raw.githubusercontent.com/#{github.fetch('repository')}/#{github.fetch('commit')}/#{path}"
  end

  private

  def download_file
    require "net/http"
    require "tempfile"

    raise IntegrityError, "Missing pinned GitHub source for #{entity_code}" unless source.key? "github"
    raise IntegrityError, errors.full_messages.to_sentence unless valid?
    uri = URI github_url
    Tempfile.create binmode: true do |download|
      Net::HTTP.start uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30 do |http|
        http.request_get uri.request_uri do |response|
          raise IntegrityError, "GitHub returned HTTP #{response.code} for #{entity_code}" unless response.is_a? Net::HTTPSuccess
          response.read_body do |chunk|
            download.write chunk
            raise IntegrityError, "File exceeds recorded size for #{entity_code}" if download.size > byte_size
          end
        end
      end
      download.flush
      download.rewind
      yield download
    end
  end

  def verify_download! path
    raise IntegrityError, "File size differs for #{entity_code}" unless File.size(path) == byte_size
    raise IntegrityError, "File checksum differs for #{entity_code}" unless Digest::SHA256.file(path).hexdigest == sha256
  end

  def github_location
    return unless source.is_a?(Hash) && source.key?("github")

    github = source["github"]
    unless github.is_a?(Hash) && github["repository"].is_a?(String) && github["repository"].match?(/\A[A-Za-z0-9_-][A-Za-z0-9_.-]*\/[A-Za-z0-9_-][A-Za-z0-9_.-]*\z/) &&
        github["commit"].is_a?(String) && github["commit"].match?(/\A[0-9a-f]{40}\z/) &&
        github["path"].is_a?(String) && github["path"].split("/", -1).none? { |part| part.in? ["", ".", ".."] } && !github["path"].include?("\\")
      errors.add :source, "must identify a GitHub repository, full commit SHA, and relative file path"
    end
  end

  def relative_media_path
    return if canonical_path&.start_with?("media/") && !canonical_path.split("/").include?("..") && !canonical_path.include?("\\")
    errors.add :canonical_path, "must be a relative path inside media/"
  end
end
