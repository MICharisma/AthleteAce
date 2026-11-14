# Minimal creation of the identities claims point at. There is no edit: a
# materially different Protocol method gets a new record so approved claims
# keep the meaning they were reviewed with.
class Admin::ClaimIdentitiesController < ApplicationController
  include FigureClaimAdmin

  MODELS = { "business" => Business, "practice" => Practice, "protocol" => Protocol, "topic" => Topic }.freeze
  FIELDS = { "business" => %w[name url founded_year description], "practice" => %w[name description],
             "protocol" => %w[name description routine], "topic" => %w[name description] }.freeze
  PREFIXES = { "business" => "BUSINESS", "practice" => "PRACTICE", "protocol" => "PROTOCOL", "topic" => "TOPIC" }.freeze

  def index
    @records = MODELS.transform_values { it.order(:name, :entity_code).to_a }
  end

  def new
    @record = model.new
  end

  def create
    values = params.fetch(:record, {}).permit(*FIELDS.fetch(params[:kind])).to_h.transform_values { it.strip.presence }
    code = params.dig(:record, :entity_code).to_s.strip.presence || FigureClaims::Codes.generate(PREFIXES.fetch(params[:kind]), values["name"])
    @record = model.new(values.merge(entity_code: FigureClaims::Codes.check!(code)))
    @record.save!
    redirect_to admin_claim_identities_path, status: :see_other, notice: "#{@record.name} added as #{@record.entity_code}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    @record ||= model.new(values)
    @error = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
    @error = "That entity code is already in use." if error.is_a?(ActiveRecord::RecordNotUnique)
    render :new, status: :unprocessable_content
  end

  private

  def model
    MODELS.fetch(params[:kind])
  end
end
