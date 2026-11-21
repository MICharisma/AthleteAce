require "net/http"

module RizzSignIn
  # Small JSON-over-HTTP client for the issuer: short timeouts, no redirects, bounded bodies.
  module HttpClient
    MAX_BYTES = 256.kilobytes

    def self.get_json(url)
      request Net::HTTP::Get.new(URI(url)), url
    end

    def self.post_form(url, params, basic_auth:)
      post = Net::HTTP::Post.new(URI(url))
      post.basic_auth(*basic_auth)
      post.set_form_data(params)
      request post, url
    end

    def self.request(http_request, url)
      uri = URI(url)
      http_request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 5) { it.request(http_request) }
      raise InvalidToken, "Rizz rejected the request with #{response.code}" if response.code.to_i.between?(400, 499)
      raise Unavailable, "Rizz returned #{response.code}" unless response.is_a?(Net::HTTPSuccess) && response.body.to_s.bytesize <= MAX_BYTES

      JSON.parse(response.body).tap { raise Unavailable, "Rizz returned a non-object response" unless it.is_a?(Hash) }
    rescue JSON::ParserError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, IOError, Net::HTTPBadResponse, Net::ProtocolError => error
      raise Unavailable, error.class.name
    end
  end
end
