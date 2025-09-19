module Payments
  module Strategies
    class WalletPayment
      def initialize(payment)
        @payment = payment
      end

      def process!
        wallet = find_wallet!
        wallet.with_lock do
          raise InsufficientFunds if wallet.balance < payment.amount

          wallet.decrement!(:balance, payment.amount)
          wallet.transactions.create!(
            amount: -payment.amount,
            type: "debit"
          )
          payment.completed!
        end
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
