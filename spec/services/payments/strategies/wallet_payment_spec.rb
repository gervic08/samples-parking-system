# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::Strategies::WalletPayment, type: :service do
  subject(:strategy) { described_class.new(payment) }

  let(:payment) { instance_double(Payment, user_id: user.id, amount: 50, completed!: true) }
  let(:user)    { instance_double(User, id: 1) }
  let(:wallet)  { instance_double(Wallet, balance: 100) }

  before do
    allow(Wallet).to receive(:find_by).with(user_id: user.id).and_return(wallet)
  end

  describe "#process!" do
    context "when wallet has sufficient funds" do
      before { allow(wallet).to receive(:debit).with(payment.amount) }

      it "debits the wallet" do
        expect(wallet).to receive(:debit).with(payment.amount)
        strategy.process!
      end

      it "marks the payment as completed" do
        allow(wallet).to receive(:debit)
        expect(payment).to receive(:completed!)
        strategy.process!
      end
    end

    context "when wallet has insufficient funds" do
      before { allow(wallet).to receive(:debit).and_raise(InsufficientFunds) }

      it "raises InsufficientFunds" do
        expect { strategy.process! }.to raise_error(InsufficientFunds)
      end

      it "does not mark the payment as completed" do
        allow(wallet).to receive(:debit).and_raise(InsufficientFunds)
        expect(payment).not_to receive(:completed!)
        expect { strategy.process! }.to raise_error(InsufficientFunds)
      end
    end

    context "when wallet is not found" do
      before do
        allow(Wallet).to receive(:find_by).with(user_id: user.id).and_return(nil)
      end

      it "raises WalletNotFound" do
        expect { strategy.process! }.to raise_error(WalletNotFound)
      end
    end
  end
end
