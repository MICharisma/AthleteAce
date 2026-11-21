module RizzSignIn
  # Verifies ES256 JWTs from the Rizz issuer against its JWKS: signature, typ,
  # iss, aud (this client), exp and iat, plus the claims each token kind needs.
  module TokenVerifier
    ID_TOKEN_TYP = "JWT".freeze
    CLAIM_HANDOFF_TYP = "rizz-claim-handoff+jwt".freeze
    CREATE_HANDOFF_TYP = "rizz-create-handoff+jwt".freeze
    LOGOUT_TYP = "logout+jwt".freeze
    BACKCHANNEL_LOGOUT_EVENT = "http://schemas.openid.net/event/backchannel-logout".freeze
    MAX_LIFETIME = 10.minutes
    CREATE_HANDOFF_LIFETIME = 5.minutes
    DISPLAY_NAME_MAX = 60
    USERNAME_FORMAT = /\A[A-Za-z0-9_]{3,24}\z/
    USERNAME_MAX = 24
    EMAIL_MAX = 255
    LEEWAY = 30

    module_function

    def verify_id_token(token, nonce:)
      claims = decode(token, typ: ID_TOKEN_TYP)
      invalid! unless claims["sub"].is_a?(String) && claims["sub"].present?
      invalid! unless claims["nonce"].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(claims["nonce"], nonce.to_s)
      invalid! unless claims["rizz_epoch"].is_a?(Integer)
      claims
    end

    def verify_claim_handoff(token)
      claims = decode(token, typ: CLAIM_HANDOFF_TYP)
      invalid! unless %w[jti operation_id speaker_label callback_uri].all? { claims[it].is_a?(String) && claims[it].present? }
      claims
    end

    # A claim handoff plus the Speaker's verified Google email (normalized here), a suggested display name and an
    # optional suggested handle (lowercased here; nil when absent or empty).
    def verify_create_handoff(token)
      claims = decode(token, typ: CREATE_HANDOFF_TYP, max_lifetime: CREATE_HANDOFF_LIFETIME)
      invalid! unless %w[jti operation_id speaker_label callback_uri email].all? { claims[it].is_a?(String) && claims[it].present? }
      invalid! unless claims["display_name"].is_a?(String) && claims["display_name"].length <= DISPLAY_NAME_MAX

      email = claims["email"].strip.downcase
      invalid! unless email.length <= EMAIL_MAX && email.match?(URI::MailTo::EMAIL_REGEXP)
      claims.merge("email" => email, "display_name" => claims["display_name"].strip, "username" => suggested_username(claims["username"]))
    end

    def suggested_username(value)
      return if value.nil? || value == ""

      invalid! unless value.is_a?(String) && value.length <= USERNAME_MAX && value.match?(USERNAME_FORMAT)
      value.downcase
    end

    def verify_logout_token(token)
      claims = decode(token, typ: LOGOUT_TYP)
      invalid! unless %w[sub jti].all? { claims[it].is_a?(String) && claims[it].present? }
      invalid! unless claims["events"].is_a?(Hash) && claims["events"].key?(BACKCHANNEL_LOGOUT_EVENT) && !claims.key?("nonce")
      invalid! unless claims["rizz_epoch"].is_a?(Integer)
      claims
    end

    def decode(token, typ:, max_lifetime: MAX_LIFETIME)
      invalid! unless token.is_a?(String) && token.bytesize <= 8.kilobytes && token.count(".") == 2

      header = JWT.decode(token, nil, false).last
      invalid! unless header["alg"] == "ES256" && header["typ"] == typ && header["kid"].is_a?(String)

      key = JwksClient.key_for(header["kid"]) or invalid!
      configuration = RizzSignIn.configuration
      claims = JWT.decode(token, key, true, algorithms: [ "ES256" ], iss: configuration.issuer, verify_iss: true,
        aud: configuration.client_id, verify_aud: true, verify_expiration: true, verify_iat: { leeway: LEEWAY },
        required_claims: %w[exp iat], leeway: LEEWAY).first
      invalid! unless claims["exp"].is_a?(Integer) && claims["iat"].is_a?(Integer) && claims["exp"] - claims["iat"] <= max_lifetime
      claims
    rescue JWT::DecodeError
      invalid!
    end

    def invalid!
      raise InvalidToken, "Invalid Rizz token"
    end
  end
end
