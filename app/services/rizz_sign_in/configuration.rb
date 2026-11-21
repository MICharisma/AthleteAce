module RizzSignIn
  class Configuration
    PRODUCTION_ISSUER = "https://rizz.micharisma.com".freeze

    def enabled?
      ENV["RIZZ_SIGN_IN_ENABLED"] == "1" && issuer_uri.present? && client_id.present? && client_secret.present?
    end

    def issuer
      ENV["RIZZ_OIDC_ISSUER"].presence&.chomp("/") || (PRODUCTION_ISSUER if Rails.env.production?)
    end

    def client_id
      ENV["RIZZ_OIDC_CLIENT_ID"].presence
    end

    def client_secret
      ENV["RIZZ_OIDC_CLIENT_SECRET"].presence
    end

    # True when url shares the issuer's scheme, host and port, and carries no credentials or fragment.
    def issuer_origin?(url)
      candidate = URI.parse(url.to_s)
      candidate.host.present? && candidate.userinfo.nil? && candidate.fragment.nil? && origin(candidate) == origin(issuer_uri)
    rescue URI::InvalidURIError
      false
    end

    private

    def issuer_uri
      uri = URI.parse(issuer.to_s)
      uri if uri.host.present? && (uri.scheme == "https" || (uri.scheme == "http" && !Rails.env.production?))
    rescue URI::InvalidURIError
      nil
    end

    def origin(uri)
      [ uri.scheme, uri.host.downcase, uri.port ]
    end
  end
end
