# Sign in with Rizz (OIDC authorization code + S256 PKCE, ID token only) and the
# claim/back-channel-logout endpoints that connect an Ace to a Rizz subject.
# Everything is off unless RIZZ_SIGN_IN_ENABLED=1 and the issuer and client
# credentials are present.
module RizzSignIn
  Error = Class.new(StandardError)
  InvalidToken = Class.new(Error)
  Unavailable = Class.new(Error)

  def self.configuration
    Configuration.new
  end

  def self.enabled?
    configuration.enabled?
  end

  # "t•••@example.com": enough for a person to recognise their own address, not enough to disclose it.
  def self.mask_email(email)
    name, domain = email.to_s.split("@", 2)
    "#{name.first}#{"•" * [ name.length - 1, 3 ].min}@#{domain}"
  end
end
