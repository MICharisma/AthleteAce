module RizzSignIn
  # The authorization-code legs of the flow: build the authorize URL and trade a code for an ID token.
  module Client
    module_function

    def authorization_url(redirect_uri:, state:, nonce:, code_challenge:)
      endpoint = JwksClient.discovery.fetch("authorization_endpoint")
      query = { client_id: RizzSignIn.configuration.client_id, redirect_uri: redirect_uri, response_type: "code", scope: "openid",
        state: state, nonce: nonce, code_challenge: code_challenge, code_challenge_method: "S256" }
      "#{endpoint}#{endpoint.include?("?") ? "&" : "?"}#{query.to_query}"
    end

    def exchange_code(code:, code_verifier:, redirect_uri:)
      configuration = RizzSignIn.configuration
      response = HttpClient.post_form(JwksClient.discovery.fetch("token_endpoint"),
        { grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, code_verifier: code_verifier },
        basic_auth: [ configuration.client_id, configuration.client_secret ].map { URI.encode_www_form_component(it) }) # RFC 6749 §2.3.1
      raise InvalidToken, "Rizz did not return an ID token" unless response["token_type"].to_s.casecmp?("bearer") && response["id_token"].is_a?(String)

      response["id_token"]
    end

    def code_challenge(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end
  end
end
