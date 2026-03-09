# frozen_string_literal: true

module Payments
  class ProcessSuccessfulPayment
    prepend ServiceTemplate::Base

    def initialize(payment)
      @payment = payment
    end

    # Main entry point: processes payment based on payable type
    def call
      return if payment.completed?

      ActiveRecord::Base.transaction do
        case payment.payable_type
        when "Wallet"
          wallet = payment.payable
          wallet.credit(payment.amount)
        when "Parking"
          parking = payment.payable
          parking.parking_bill.update!(paid_at: Time.current)
        when "Vehicle"
          vehicle = payment.payable
          paid_bills = vehicle.unpaid_bills.update_all(paid_at: Time.current)
          raise ActiveRecord::RecordInvalid, "No bills to be paid" if paid_bills.zero?
        else
          raise InvalidPaymentType
        end

        payment.completed!
      end
    rescue StandardError => e
      payment&.failed!
      Sentry.capture_exception(e, extra: {payment_id: payment.id})
      Rails.logger.error("Failed to process payment: #{e.message}")
      raise e
    end

    private

    attr_reader :payment
  end
end
