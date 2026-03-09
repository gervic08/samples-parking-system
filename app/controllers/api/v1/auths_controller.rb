# frozen_string_literal: true

class Api::V1::AuthsController < Api::BaseController
  ACCESS_TOKEN_EXPIRATION = 2.minutes
  REFRESH_TOKEN_EXPIRATION = 10.minutes

  skip_before_action :authenticate_api_token!, only: [:create, :refresh]
  skip_before_action :ensure_onboarded!, only: [:create, :refresh]
  skip_before_action :set_request_details, only: [:create, :refresh]
  before_action :authenticate, only: [:create]
  before_action :authenticate_refresh_token!, only: [:refresh]
  before_action :authenticate_api_token!, only: [:destroy]

  # POST /api/v1/auth
  # Authenticates user and returns JWT and refresh token
  def create
    access_token = generate_jwt_token
    refresh_token = generate_refresh_token

    device = user.devices.find_or_initialize_by(device_params.slice(:device_type, :fcm_token)) do |d|
      d.fcm_token_expires_at = device_params[:fcm_token_expires_at]
      d.metadata = device_params[:metadata]
    end
    device.save! if device.new_record?

    render json: UserBlueprint.render(user,
      access_token: access_token,
      refresh_token: refresh_token), status: :ok
  end

  # POST /api/v1/auth/refresh
  # Returns a new access token using a valid refresh token
  def refresh
    access_token = generate_jwt_token
    render json: {access_token: access_token}, status: :ok
  end

  # DELETE /api/v1/auth
  # Blacklists the current JWT token
  def destroy
    TokenBlacklist.blacklist!(token_from_header)
    render json: {message: "Successfully logged out"}, status: :ok
  end

  private

  def authenticate
    raise ActiveRecord::RecordNotFound unless user&.kept?
    unless user&.valid_password?(params[:password])
      render json: {error: error_message}, status: :unauthorized
    end
  end

  def user
    @user ||= Profile.find_by(
      cellphone_number: params[:cellphone_number],
      cellphone_area_code: params[:cellphone_area_code],
      cellphone_country_code: params[:cellphone_country_code]
    )&.user
  end

  def generate_jwt_token
    JsonWebToken.encode(
      user_id: user.id,
      exp: ACCESS_TOKEN_EXPIRATION.from_now.to_i,
      jti: SecureRandom.uuid
    )
  end

  def generate_refresh_token
    JsonWebToken.encode(
      user_id: user.id,
      refresh_token: true,
      exp: REFRESH_TOKEN_EXPIRATION.from_now.to_i,
      jti: SecureRandom.uuid
    )
  end

  def error_message
    I18n.t("devise.failure.invalid", authentication_keys: :cellphone)
  end

  def device_params
    params.require(:device).permit(:fcm_token, :device_type, :fcm_token_expires_at, :metadata)
  end
end
