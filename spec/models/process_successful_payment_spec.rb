require "rails_helper"

RSpec.describe Payments::ProcessSuccessfulPayment do
  let(:account) { create(:account) }
  let(:user) { create(:user, :onboarded, roles: {driver: true}) }
  let(:vehicle) { create(:vehicle, created_by_user_id: user.id, plate: "AA297EL", image: fixture_file_upload("test.png", "image/png")) }
  let!(:vehicle_ownership) { VehicleOwnership.create!(vehicle: vehicle, user: user) }
  let(:wallet) { create(:wallet, user: user) }

  subject(:service) { described_class.new(payment) }

  describe "#call" do
    context "when processing wallet recharge" do
      let(:payment) do
        create(:payment,
          user: user,
          payable: wallet,
          amount: 1000,
          payment_type: "wallet_recharge",
          payment_method: "card_payment",
          status: "pending")
      end

      it "credits the wallet and marks payment as completed" do
        expect { service.call }.to change { wallet.reload.balance }.by(payment.amount)

        expect(payment.reload).to be_completed
      end

      context "when payment is already completed" do
        before { payment.update!(status: :completed) }

        it "does not process the payment again" do
          expect { service.call }.not_to change { wallet.reload.balance }
        end
      end

      context "when wallet crediting fails" do
        before do
          allow(wallet).to receive(:credit).and_raise(ActiveRecord::RecordInvalid)
        end

        it "marks payment as failed and raises error" do
          expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

          expect(payment.reload).to be_failed
        end
      end
    end

    context "when processing parking payment" do
      let(:parking) { create(:parking, block: create(:block), started_at_user_id: user.id, start_at: Time.now - 2.hours, vehicle: vehicle, ended_at_user_id: user.id, ended_by_role: "driver") }
      let!(:parking_bill) { create(:parking_bill, parking: parking, amount: 1200, paid_at: nil) }
      let(:payment) do
        create(:payment,
          user: user,
          payable: parking,
          amount: parking_bill.amount,
          payment_type: "parking_payment",
          payment_method: "card_payment",
          status: "pending")
      end

      it "marks parking bill as paid and completes payment" do
        service.call

        expect(parking_bill.reload.paid_at).to be_present
        expect(payment.reload).to be_completed
      end

      context "when payment is already completed" do
        before { payment.update!(status: :completed) }

        it "does not process the payment again" do
          expect { service.call }.not_to change { parking_bill.reload.paid_at }
        end
      end

      context "when parking bill update fails" do
        before do
          allow(parking_bill).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        end

        it "marks payment as failed and raises error" do
          expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

          expect(payment.reload).to be_failed
        end
      end
    end

    context "when processing vehicle debt payment" do
      let!(:unpaid_bills) do
        [
          create(:parking_bill, parking: create(:parking, vehicle: vehicle, started_at_user_id: user.id, start_at: Time.now - 10.hours, end_at: Time.now - 8.hours), amount: 500, paid_at: nil),
          create(:parking_bill, parking: create(:parking, vehicle: vehicle, started_at_user_id: user.id, start_at: Time.now - 4.hours, end_at: Time.now - 2.hours), amount: 700, paid_at: nil)
        ]
      end

      let(:payment) do
        create(:payment,
          user: user,
          payable: vehicle,
          amount: 1200,
          payment_type: "vehicle_debt_payment",
          payment_method: "card_payment",
          status: "pending")
      end

      it "marks all unpaid bills as paid and completes payment" do
        service.call

        expect(unpaid_bills.map(&:reload).map(&:paid_at)).to all(be_present)
        expect(payment.reload).to be_completed
      end

      context "when payment is already completed" do
        before { payment.update!(status: :completed) }

        it "does not process the payment again" do
          expect { service.call }.not_to change { unpaid_bills.first.reload.paid_at }
        end
      end

      context "when bill update fails" do
        before do
          allow(vehicle).to receive_message_chain(:unpaid_bills, :update_all).and_raise(ActiveRecord::RecordInvalid)
        end

        it "marks payment as failed and raises error" do
          expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

          expect(payment.reload).to be_failed
        end
      end
    end
  end
end
