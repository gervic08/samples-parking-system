class Api::V1::PaymentsController < Api::BaseController
  before_action :authenticate_api_token!

  # POST /api/v1/payments
  def create
    payment = current_user.payments.build(payment_params)

    if payment.save
      Payments::ProcessSuccessfulPayment.new(payment).call
      render json: PaymentBlueprint.render(payment), status: :created
    else
      render json: { errors: payment.errors.full_messages }, status: :unprocessable_entity
    end
  rescue InsufficientFunds, WalletNotFound => e
    render json: { error: e.class.to_s }, status: :payment_required
  rescue StandardError => e
    Sentry.capture_exception(e)
    render json: { error: "Payment processing failed" }, status: :internal_server_error
  end

  private

  def payment_params
    params.require(:payment).permit(:amount, :payable_type, :payable_id, :payment_method)
  end
end
