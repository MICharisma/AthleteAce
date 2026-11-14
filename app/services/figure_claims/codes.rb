module FigureClaims
  # Entity codes for admin-entered records, in the seed catalog's format.
  module Codes
    FORMAT = /\A[A-Z0-9]+(?:[-_][A-Z0-9]+)*\z/

    def self.generate(prefix, name = nil)
      slug = I18n.transliterate(name.to_s).upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
      slug = SecureRandom.uuid.upcase if slug.empty?
      "#{prefix}-#{slug}"
    end

    def self.check!(code)
      raise ArgumentError, "Entity codes use capital letters, digits, hyphens and underscores, like BUSINESS-HARBOR_COFFEE." unless code.to_s.match?(FORMAT)
      code
    end
  end
end
