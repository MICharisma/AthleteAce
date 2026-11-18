# Shared setup for the admin pages that curate Figure claims.
module FigureClaimAdmin
  extend ActiveSupport::Concern

  KINDS = { "business" => FigureBusinessRelationship, "practice" => FigurePracticeRelationship,
            "statement" => AttributedStatement }.freeze

  included do
    before_action :authenticate_ace!
    before_action :require_admin!
    before_action { response.headers["Cache-Control"] = "private, no-store" }
    helper_method :claim_kind
  end

  private

  def claim_model
    KINDS.fetch(params[:kind]) { raise ActiveRecord::RecordNotFound }
  end

  def claim_kind(claim)
    KINDS.key(claim.class)
  end

  def resolve_figure(code)
    return if code.blank?

    EntityCode.resolve(Figure, code.strip) || raise(ArgumentError, "No Figure has the code #{code}.")
  end
end
