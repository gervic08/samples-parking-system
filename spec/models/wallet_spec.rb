# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallet, type: :model do
  subject(:wallet) { build(:wallet, balance: 100) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:transactions) }
  end

  describe "validations" do
    context "when user is not a driver" do
      it "is invalid" do
        wallet.user = build(:user, :admin)
        expect(wallet).not_to be_valid
        expect(wallet.errors[:user]).to include("must be a driver")
      end
    end

    context "when user is a driver" do
      it "is valid" do
        wallet.user = build(:user, :driver)
        expect(wallet).to be_valid
      end
    end
  end

  describe "#can_debit?" do
    it "returns true when balance covers the amount" do
      expect(wallet.can_debit?(50)).to be true
    end

    it "returns true when balance equals the amount" do
      expect(wallet.can_debit?(100)).to be true
    end

    it "returns false when balance is below the amount" do
      expect(wallet.can_debit?(101)).to be false
    end
  end

  describe "#credit" do
    it "increases the balance and creates a credit transaction" do
      expect { wallet.credit(50) }
        .to change { wallet.reload.balance }.by(50)
        .and change { wallet.transactions.count }.by(1)
    end

    it "creates a transaction with the correct attributes" do
      wallet.credit(50)
      transaction = wallet.transactions.last
      expect(transaction.amount).to eq(50)
      expect(transaction.type).to eq("credit")
    end
  end

  describe "#debit" do
    it "decreases the balance and creates a debit transaction" do
      expect { wallet.debit(30) }
        .to change { wallet.reload.balance }.by(-30)
        .and change { wallet.transactions.count }.by(1)
    end

    it "creates a transaction with the correct attributes" do
      wallet.debit(30)
      transaction = wallet.transactions.last
      expect(transaction.amount).to eq(-30)
      expect(transaction.type).to eq("debit")
    end

    it "raises InsufficientFunds when balance is too low" do
      expect { wallet.debit(200) }.to raise_error(InsufficientFunds)
    end

    it "does not modify balance when InsufficientFunds is raised" do
      expect { wallet.debit(200) }.to raise_error(InsufficientFunds)
      expect(wallet.reload.balance).to eq(100)
    end
  end

  describe "#kept?" do
    context "when wallet and user are not discarded" do
      it "returns true" do
        allow(wallet).to receive(:undiscarded?).and_return(true)
        allow(wallet.user).to receive(:kept?).and_return(true)
        expect(wallet.kept?).to be true
      end
    end

    context "when wallet is discarded" do
      it "returns false" do
        allow(wallet).to receive(:undiscarded?).and_return(false)
        expect(wallet.kept?).to be false
      end
    end

    context "when user is not kept" do
      it "returns false" do
        allow(wallet).to receive(:undiscarded?).and_return(true)
        allow(wallet.user).to receive(:kept?).and_return(false)
        expect(wallet.kept?).to be false
      end
    end
  end
end
