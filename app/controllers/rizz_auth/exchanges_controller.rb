# Server-to-server: the Rizz Speaker spends a browser's claim receipt (HTTP Basic client credentials).
class RizzAuth::ExchangesController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_action :authenticate_client

  def create
    operation_id, receipt, rizz_sub, epoch = params.values_at(:operation_id, :receipt, :rizz_sub, :rizz_session_epoch)
    unless [ operation_id, receipt, rizz_sub ].all? { it.is_a?(String) && it.present? } && epoch.to_s.match?(/\A[1-9]\d{0,8}\z/)
      return render json: { error: "invalid_request" }, status: :bad_request
    end

    result = RizzSignIn::ClaimExchange.call(operation_id: operation_id, receipt: receipt, rizz_sub: rizz_sub, rizz_session_epoch: epoch.to_i)
    case result.status
    when :ok then render json: { ok: true, local_handle: result.ace.handle || result.ace.email, has_independent_recovery: result.ace.confirmed? }
    when :conflict then render json: { error: "conflict" }, status: :conflict
    else render json: { error: "invalid_receipt" }, status: :bad_request
    end
  end

  private

  def authenticate_client
    configuration = RizzSignIn.configuration
    authenticate_or_request_with_http_basic("Rizz") do |client_id, client_secret|
      ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(client_id), Digest::SHA256.hexdigest(configuration.client_id)) &
        ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(client_secret), Digest::SHA256.hexdigest(configuration.client_secret))
    end
  end
end
