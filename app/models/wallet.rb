# frozen_string_literal: true

class Wallet < ApplicationRecord
  include Discard::Model

  has_paper_trail only: %i[balance]

  belongs_to :user
  has_many :transactions

  ALLOWED_NEGATIVE_BALANCE = 0
  private_constant :ALLOWED_NEGATIVE_BALANCE

  validate :must_be_driver

  scope :kept, -> { undiscarded.joins(:user).merge(User.kept) }

  def kept?
    undiscarded? && user.kept?
  end

  def credit(amount)
    with_lock do
      ActiveRecord::Base.transaction do
        transactions.create!(amount: amount, type: "credit")
        update!(balance: balance + amount)
      end
    end
  end

  def can_debit?(amount)
    balance + ALLOWED_NEGATIVE_BALANCE >= amount
  end

  def debit(amount)
    raise InsufficientFunds unless can_debit?(amount)

    with_lock do
      ActiveRecord::Base.transaction do
        transactions.create!(amount: -amount, type: "debit")
        update!(balance: balance - amount)
      end
    end
  end

  private

  def must_be_driver
    errors.add(:user, "must be a driver") unless user.driver?
  end
end
