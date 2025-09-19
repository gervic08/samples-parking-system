class Api::BaseController < ActionController::API
  include ActiveStorage::SetCurrent
  include Authentication
  include Authorization
  include CurrentHelper
  include Pagy::Backend
  include SetCurrentRequestDetails
  include Api::ErrorHandler

  before_action :authenticate_api_token!
  before_action :ensure_onboarded!

  def logged_as?(role)
    role_logged == role.to_s
  end

  def role_logged
    role = request.headers["X-Role"].to_s
    return unless current_user.active_roles.include?(role)
    role
  end

  private

  def authenticate_api_token!
    head :unauthorized unless current_user
  end

  def ensure_onboarded!
    raise CellphoneNotVerified unless current_user.cellphone_verified_at.present?
  end

  def authenticate_refresh_token!
    token = token_from_header
    return render json: {error: "Refresh token required"}, status: :unauthorized unless token

    begin
      decoded = JsonWebToken.decode(token)
      @user = User.find(decoded[:user_id])
      render json: {error: "Invalid refresh token"}, status: :unauthorized unless decoded[:refresh_token]
    rescue JWT::DecodeError
      render json: {error: "Invalid refresh token"}, status: :unauthorized
    end
  end

  def authorize_user!(role)
    role = role.to_sym
    return if logged_as?(:admin)

    case role
    when :puper, :superpuper
      raise NotAuthorized unless current_account_user && logged_as?(role)
    when :driver
      raise NotAuthorized unless logged_as?(role)
    end
  end

  def token_from_header
    request.headers.fetch("Authorization", "").split(" ").last
  end

  def user_from_token
    decoded_token = JsonWebToken.decode(token_from_header)
    return nil unless decoded_token

    user_id = decoded_token[:user_id]

    @user_from_token ||= User.find_by(id: user_id)
  end

  def current_user
    @current_user ||= user_from_token
  end
end
