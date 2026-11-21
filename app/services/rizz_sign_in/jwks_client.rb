module RizzSignIn
  # Fetches and caches the issuer's discovery document and ES256 signing keys.
  # An unknown kid triggers one refresh, at most once per REFRESH_INTERVAL.
  class JwksClient
    CACHE_TTL = 1.hour
    REFRESH_INTERVAL = 30.seconds
    State = Struct.new(:discovery, :discovery_at, :keys, :keys_at, :refreshed_at)

    class << self
      def discovery
        state = synchronize { state_for_issuer }
        load_discovery(state) unless state.discovery && state.discovery_at > CACHE_TTL.ago
        state.discovery
      end

      def key_for(kid)
        state = synchronize { state_for_issuer }
        refresh_keys(state) unless state.keys && state.keys_at > CACHE_TTL.ago
        state.keys[kid] || refresh_for_unknown_kid(state, kid)
      end

      def reset!
        synchronize { @states = {} }
      end

      private

      def mutex
        @mutex ||= Mutex.new
      end

      def synchronize(&block)
        mutex.synchronize(&block)
      end

      def state_for_issuer
        (@states ||= {})[RizzSignIn.configuration.issuer] ||= State.new
      end

      def refresh_for_unknown_kid(state, kid)
        # Check and stamp together so concurrent requests for an unknown kid cannot all refresh.
        due = synchronize do
          next false unless state.refreshed_at.nil? || state.refreshed_at < REFRESH_INTERVAL.ago

          state.refreshed_at = Time.current
        end
        return unless due

        refresh_keys(state)
        state.keys[kid]
      end

      def load_discovery(state)
        configuration = RizzSignIn.configuration
        document = HttpClient.get_json("#{configuration.issuer}/.well-known/openid-configuration")
        endpoints = document.values_at("authorization_endpoint", "token_endpoint", "jwks_uri")
        unless document["issuer"] == configuration.issuer && endpoints.all? { configuration.issuer_origin?(it) }
          raise Unavailable, "Rizz discovery document does not match the configured issuer"
        end

        synchronize { state.discovery, state.discovery_at = document, Time.current }
      end

      def refresh_keys(state)
        load_discovery(state) unless state.discovery
        document = HttpClient.get_json(state.discovery["jwks_uri"])
        keys = Array(document["keys"]).filter_map { parse_key(it) }.to_h
        synchronize { state.keys, state.keys_at, state.refreshed_at = keys, Time.current, Time.current }
      rescue Unavailable
        raise if state.keys.nil?

        # Keep serving the keys we have and retry after REFRESH_INTERVAL instead of on every request.
        synchronize { state.refreshed_at, state.keys_at = Time.current, Time.current - CACHE_TTL + REFRESH_INTERVAL }
      end

      def parse_key(jwk)
        return unless jwk.is_a?(Hash) && jwk["kty"] == "EC" && jwk["crv"] == "P-256" && jwk["kid"].is_a?(String)
        return unless jwk["alg"].in?([ nil, "ES256" ]) && jwk["use"].in?([ nil, "sig" ])

        [ jwk["kid"], JWT::JWK.import(jwk).verify_key ]
      rescue JWT::JWKError, OpenSSL::PKey::PKeyError
        nil
      end
    end
  end
end
