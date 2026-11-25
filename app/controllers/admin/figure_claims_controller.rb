class Admin::FigureClaimsController < ApplicationController
  include FigureClaimAdmin

  FIELDS = {
    "business" => %w[business_id predicate start_date end_date temporal_state as_of_date compensation compensation_description vehicle_name context],
    "practice" => %w[protocol_id predicate interpretation start_date end_date temporal_state as_of_date context],
    "statement" => %w[attribution_kind text topic_id figure_practice_relationship_id staff_tenure_id observer_name statement_date context]
  }.freeze
  CODE_PREFIXES = { "business" => "BUSINESS_TIE", "practice" => "PRACTICE_TIE", "statement" => "STATEMENT" }.freeze
  LIST_LIMIT = 100

  before_action :load_claim, only: [ :show, :edit, :update, :review ]

  def index
    @status = params[:status].presence_in(ReviewedClaim::STATUSES) || "pending"
    @kind = params[:kind].presence_in(FigureClaimAdmin::KINDS.keys)
    models = @kind ? [ FigureClaimAdmin::KINDS[@kind] ] : FigureClaimAdmin::KINDS.values
    @counts = ReviewedClaim::STATUSES.index_with { |status| models.sum { it.with_status(status).count } }
    @claims = models.flat_map { it.with_status(@status).includes(:figure).order(updated_at: :desc).limit(LIST_LIMIT) }
      .sort_by { [ -it.updated_at.to_f, it.entity_code ] }.first(LIST_LIMIT)
  end

  def show
    prepare_review
  end

  def new
    @claim = claim_model.new(entity_code: FigureClaims::Codes.generate(CODE_PREFIXES.fetch(params[:kind]), SecureRandom.hex(4)))
    @figure_code = params[:figure_code]
    prepare_form
  end

  def create
    @claim = claim_model.new(entity_code: FigureClaims::Codes.check!(params.dig(:claim, :entity_code).to_s.strip))
    @figure_code = params.dig(:claim, :figure_code)
    FigureClaims::Edit.call(claim: @claim, attributes: claim_attributes, practice_ids: practice_ids)
    redirect_to admin_figure_claim_path(params[:kind], @claim), status: :see_other, notice: "Claim saved as pending. Add its evidence."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    form_error :new, error
  end

  def edit
    @figure_code = @claim.figure.entity_code
    prepare_form
  end

  def update
    @figure_code = params.dig(:claim, :figure_code)
    FigureClaims::Edit.call(claim: @claim, attributes: claim_attributes, revision: params[:revision], practice_ids: practice_ids)
    redirect_to admin_figure_claim_path(params[:kind], @claim), status: :see_other,
      notice: @claim.saved_changes? || @claim.pending? ? "Saved. The claim is pending review." : "No changes to save."
  rescue FigureClaims::Edit::Conflict => error
    form_error :edit, error, status: :conflict
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => error
    form_error :edit, error
  end

  def review
    FigureClaims::Review.call(claim: @claim, actor: current_ace, action: params[:review_action], revision: params[:revision],
      status: params[:status], digest: params[:digest], reason: params[:reason])
    redirect_to admin_figure_claim_path(params[:kind], @claim), status: :see_other, notice: "Decision recorded."
  rescue FigureClaims::Review::Forbidden => error
    render plain: error.message, status: :forbidden
  rescue FigureClaims::Review::Conflict, ArgumentError => error
    @claim.reload
    @error = error.message
    prepare_review
    render :show, status: error.is_a?(ArgumentError) ? :unprocessable_content : :conflict
  end

  private

  def load_claim
    @claim = claim_model.find(params[:id])
  end

  def prepare_review
    @digest = @claim.review_digest
    @problems = @claim.publication_problems
    @decisions = @claim.moderation_decisions.includes(:actor).reverse
  end

  def prepare_form
    @businesses = Business.order(:name, :entity_code)
    @protocols = Protocol.order(:name, :entity_code)
    @practices = Practice.order(:name, :entity_code)
    @topics = Topic.order(:name)
    figure = @claim.figure || (resolve_figure(@figure_code) rescue nil)
    @staff_tenures = figure ? figure.staff_tenures.newest_first.includes(:organization, :team) : []
    @practice_claims = figure ? figure.figure_practice_relationships.includes(:protocol).order(:entity_code) : []
  end

  def claim_attributes
    values = params.fetch(:claim, {}).permit(*FIELDS.fetch(params[:kind])).to_h
    values.transform_values! { it.is_a?(String) ? it.strip.presence : it }
    values["figure"] = resolve_figure(@figure_code) || raise(ArgumentError, "Enter the Figure's entity code.")
    values["observer"] = resolve_figure(params.dig(:claim, :observer_code)) if params[:kind] == "statement"
    values
  end

  def practice_ids
    params.dig(:claim, :practice_ids) || [] if params[:kind] == "practice"
  end

  def form_error(template, error, status: :unprocessable_content)
    @error = error.is_a?(ActiveRecord::RecordNotUnique) ? "That entity code is already in use." : error.message
    @error = error.record.errors.full_messages.to_sentence if error.is_a?(ActiveRecord::RecordInvalid)
    prepare_form
    render template, status: status
  end
end
