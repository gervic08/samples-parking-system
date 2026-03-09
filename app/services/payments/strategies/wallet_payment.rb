# frozen_string_literal: true

module Payments
  module Strategies
    class WalletPayment
      def initialize(payment)
        @payment = payment
      end

      def process!
        wallet = find_wallet!
        wallet.debit(payment.amount)
        payment.completed!
      end

      private

      attr_reader :payment

      def find_wallet!
        wallet = Wallet.find_by(user_id: payment.user_id)
        raise WalletNotFound unless wallet
        wallet
      end
    end
  end
end
