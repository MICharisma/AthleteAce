class Admin::AttestationsController < ApplicationController
  include FigureClaimAdmin

  FIELDS = %w[content_form body url media_url excerpt locator author_name source_title publisher published_on captured_at context].freeze

  before_action :load_claim
  before_action :load_attestation, only: [ :edit, :update, :destroy ]

  def new
    @attestation = @claim.attestations.new(entity_code: FigureClaims::Codes.generate("ATTESTATION", SecureRandom.hex(4)),
      content_form: "link", captured_at: Time.current.change(sec: 0))
  end

  def create
    @attestation = Attestation.new(claim: @claim, entered_by: current_ace,
      entity_code: FigureClaims::Codes.check!(params.dig(:attestation, :entity_code).to_s.strip))
    save_attestation :new
  end

  def edit
  end

  def update
    save_attestation :edit
  end

  def destroy
    @attestation.destroy!
    redirect_to admin_figure_claim_path(params[:kind], @claim), status: :see_other, notice: "Attestation removed. The claim is pending review."
  end

  private

  def load_claim
    @claim = claim_model.find(params[:claim_id])
  end

  def load_attestation
    @attestation = @claim.attestations.find(params[:id])
  end

  def save_attestation(template)
    values = params.fetch(:attestation, {}).permit(*FIELDS).to_h.transform_values { it.strip.presence }
    values["author"] = resolve_figure(params.dig(:attestation, :author_code))
    values["captured_at"] ||= Time.current if @attestation.new_record?
    @attestation.update! values
    redirect_to admin_figure_claim_path(params[:kind], @claim), status: :see_other, notice: "Attestation saved. The claim is pending review."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    @error = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
    @error = "That entity code is already in use." if error.is_a?(ActiveRecord::RecordNotUnique)
    render template, status: :unprocessable_content
  end
end
