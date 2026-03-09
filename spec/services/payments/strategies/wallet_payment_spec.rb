require "rails_helper"

RSpec.describe Payments::Strategies::WalletPayment do
  let(:account) { create(:account) }
  let(:user) { create(:user, :onboarded, roles: {driver: true}) }
  let(:wallet) { create(:wallet, user: user, balance: 2000) }
  let(:payment) { create(:payment) }

  subject(:strategy) { described_class.new(payment) }

  describe "#process" do
    context "when processing wallet payment" do
      let(:payment) do
        create(:parking_payment,
          user: user,
          amount: 1000,
          payment_method: "wallet_payment")
      end

      it "debits wallet and marks payment completed" do
        expect { strategy.process! }.to change { wallet.reload.balance }.by(-1000)
        expect(payment.reload).to be_completed
      end

      it "creates a wallet transaction" do
        expect { strategy.process! }.to change(wallet.transactions, :count).by(1)

        transaction = wallet.transactions.last
        expect(transaction).to have_attributes(
          wallet: wallet,
          amount: -1000,
          type: "debit"
        )
      end
    end

    context "when wallet has insufficient funds" do
      let(:payment) { create(:vehicle_debt_payment, user: user, amount: 2500) }

      it "raises InsufficientFundsError" do
        wallet
        expect { strategy.process! }.to raise_error(InsufficientFunds)
      end

      it "does not create wallet transaction" do
        expect do
          begin
            strategy.process!
          rescue InsufficientFunds
            nil
          end
        end.not_to change(wallet.transactions, :count)
      end
    end

    context "when wallet is not found" do
      let(:payment) { create(:vehicle_debt_payment, user: user, amount: 2500) }

      it "raises WalletNotFoundError" do
        expect { strategy.process! }.to raise_error(WalletNotFound)
      end
    end

    context "when concurrent wallet operations occur" do
      let(:payment) do
        create(:parking_payment,
          user: user,
          amount: 1000,
          payment_method: "wallet_payment")
      end

      it "handles race conditions with database locks" do
        expect(wallet).to receive(:with_lock).and_call_original
        strategy.process!
      end
    end
  end
end
