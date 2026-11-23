class Api::V1::ShotsController < ActionController::API
  before_action { response.headers["Cache-Control"] = "no-store" }
  before_action :authenticate_upload_token

  def create
    shot, created = ShotUpload.new(token: @token, key: request.headers["Idempotency-Key"].to_s,
      image: params[:image], metadata: params.fetch(:metadata, "{}")).call
    render json: {
      id: shot.id, image_path: shot.url, tags: shot.tags,
      captures: shot.captures.includes(:player).map do |capture|
        { id: capture.id, player_entity_code: capture.player.entity_code, weight: capture.weight }
      end
    }, status: created ? :created : :ok
  rescue ShotUpload::Conflict => error
    render json: { error: error.message }, status: :conflict
  rescue ShotUpload::Invalid, ActiveRecord::RecordInvalid => error
    render json: { error: error.message }, status: :unprocessable_content
  end

  private

  def authenticate_upload_token
    secret = request.authorization.to_s[/\ABearer ([^\s]+)\z/i, 1]
    @token = ShotUploadToken.authenticate(secret)
    return if @token

    response.headers["WWW-Authenticate"] = 'Bearer realm="Shot uploads"'
    render json: { error: "A valid Shot upload token is required." }, status: :unauthorized
  end
end
