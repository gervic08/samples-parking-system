require "rails_helper"

RSpec.describe Wallet, type: :model do
  let(:user) { create(:user, roles: {driver: true}) }
  let(:wallet) { create(:wallet, user: user) }

  describe "#credit" do
    it "creates a transaction and updates the balance" do
      expect do
        wallet.credit(100)
      end.to change(wallet.transactions, :count).by(1)
        .and change(wallet, :balance).by(100)
    end
  end

  describe "#debit" do
    it "creates a transaction and updates the balance" do
      wallet.credit(100)

      expect do
        wallet.debit(50)
      end.to change(wallet.transactions, :count).by(1)
        .and change(wallet, :balance).by(-50)
    end

    it "raises an error if there are not enough funds" do
      expect do
        wallet.debit(50)
      end.to raise_error(InsufficientFunds)
    end
  end
end
