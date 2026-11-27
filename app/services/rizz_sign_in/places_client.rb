require "cgi"
require "json"
require "net/http"
require "openssl"
require "uri"

module RizzSignIn
  # Fetches the places and trips a speaker has shared with AthleteAce from Rizz.
  # Places remain owned by Rizz and are read live rather than duplicated locally.
  class PlacesClient
    MAX_BYTES = 256 * 1024
    OPEN_TIMEOUT = 3
    READ_TIMEOUT = 5
    WRITE_TIMEOUT = 5

    Result = Data.define(:status, :places, :trips, :current_zone, :error) do
      def ok?
        status == :ok
      end

      def disconnected?
        status == :disconnected
      end

      def unavailable?
        status == :unavailable
      end
    end

    def self.fetch(rizz_sub:, configuration: RizzSignIn.configuration)
      new(configuration: configuration).fetch(rizz_sub: rizz_sub)
    end

    def self.manage_url(configuration: RizzSignIn.configuration)
      issuer = configuration.issuer.to_s.strip.chomp("/")
      return if issuer.blank?

      "#{issuer}/places"
    end

    def initialize(configuration: RizzSignIn.configuration)
      @configuration = configuration
    end

    def fetch(rizz_sub:)
      return empty_result(:disabled) unless @configuration.configured?
      return empty_result(:not_found) if rizz_sub.blank?

      uri = endpoint_uri(rizz_sub)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request.basic_auth(@configuration.client_id.to_s, @configuration.client_secret.to_s)

      interpret perform(uri, request)
    rescue URI::InvalidURIError, JSON::ParserError, SystemCallError, SocketError, Timeout::Error,
           OpenSSL::SSL::SSLError, IOError, Net::HTTPBadResponse, Net::ProtocolError => error
      empty_result(:unavailable, error: error.class.name)
    end

    private

    def endpoint_uri(rizz_sub)
      base = @configuration.issuer.to_s.strip.chomp("/")
      uri = URI.parse("#{base}/api/v1/speakers/#{CGI.escape(rizz_sub.to_s)}/places")
      raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri
    end

    def perform(uri, request)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        write_timeout: WRITE_TIMEOUT
      ) { |http| http.request(request) }
    end

    def interpret(response)
      code = response.code.to_i
      return empty_result(:disconnected, error: "410") if code == 410
      return empty_result(:not_found, error: "404") if code == 404

      body = response.body.to_s
      unless response.is_a?(Net::HTTPSuccess) && body.bytesize <= MAX_BYTES
        return empty_result(:unavailable, error: "HTTP #{code}")
      end

      parsed = JSON.parse(body)
      return empty_result(:unavailable, error: "Invalid payload") unless parsed.is_a?(Hash)

      Result.new(
        status: :ok,
        places: Array(parsed["places"]).select { |item| item.is_a?(Hash) },
        trips: Array(parsed["trips"]).select { |item| item.is_a?(Hash) },
        current_zone: parsed["current_zone"].is_a?(Hash) ? parsed["current_zone"] : nil,
        error: nil
      )
    end

    def empty_result(status, error: nil)
      Result.new(status: status, places: [], trips: [], current_zone: nil, error: error)
    end
  end
end
