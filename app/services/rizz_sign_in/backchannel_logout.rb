module RizzSignIn
  # Applies a verified logout token: each jti is processed once, the binding's epoch only moves forward,
  # and the binding is marked disconnected so Rizz-opened sessions end on their next request.
  module BackchannelLogout
    module_function

    def call(claims)
      ApplicationRecord.transaction do
        RizzBackchannelLogoutEvent.create!(jti: claims["jti"], rizz_sub: claims["sub"], rizz_epoch: claims["rizz_epoch"], processed_at: Time.current)
        binding = AceRizzBinding.lock.find_by(rizz_sub: claims["sub"])
        binding&.update!(rizz_session_epoch: [ binding.rizz_session_epoch + 1, claims["rizz_epoch"] ].max,
          status: "disconnected", disconnected_at: Time.current)
      end
    rescue ActiveRecord::RecordNotUnique
      nil # redelivered jti; already applied
    end
  end
end
