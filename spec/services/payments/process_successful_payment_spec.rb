# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::ProcessSuccessfulPayment, type: :service do
  subject(:service) { described_class.new(payment) }

  let(:payment) { instance_double(Payment, id: 1, completed?: false, completed!: true, failed!: true) }

  describe "#call" do
    context "when payment is already completed" do
      before { allow(payment).to receive(:completed?).and_return(true) }

      it "does nothing" do
        expect(payment).not_to receive(:completed!)
        service.call
      end
    end

    context "when payable_type is Wallet" do
      let(:wallet) { instance_double(Wallet) }

      before do
        allow(payment).to receive(:payable_type).and_return("Wallet")
        allow(payment).to receive(:payable).and_return(wallet)
        allow(payment).to receive(:amount).and_return(100)
        allow(wallet).to receive(:credit).with(100)
      end

      it "credits the wallet" do
        expect(wallet).to receive(:credit).with(100)
        service.call
      end

      it "marks the payment as completed" do
        expect(payment).to receive(:completed!)
        service.call
      end
    end

    context "when payable_type is Parking" do
      let(:parking)      { instance_double(Parking) }
      let(:parking_bill) { instance_double(ParkingBill) }

      before do
        allow(payment).to receive(:payable_type).and_return("Parking")
        allow(payment).to receive(:payable).and_return(parking)
        allow(parking).to receive(:parking_bill).and_return(parking_bill)
        allow(parking_bill).to receive(:update!).with(paid_at: anything)
      end

      it "marks the parking bill as paid" do
        expect(parking_bill).to receive(:update!).with(paid_at: anything)
        service.call
      end

      it "marks the payment as completed" do
        expect(payment).to receive(:completed!)
        service.call
      end
    end

    context "when payable_type is Vehicle" do
      let(:vehicle)       { instance_double(Vehicle) }
      let(:unpaid_bills)  { instance_double(ActiveRecord::Relation) }

      before do
        allow(payment).to receive(:payable_type).and_return("Vehicle")
        allow(payment).to receive(:payable).and_return(vehicle)
        allow(vehicle).to receive(:unpaid_bills).and_return(unpaid_bills)
        allow(unpaid_bills).to receive(:update_all).with(paid_at: anything).and_return(2)
      end

      it "marks all unpaid bills as paid" do
        expect(unpaid_bills).to receive(:update_all).with(paid_at: anything)
        service.call
      end

      it "marks the payment as completed" do
        expect(payment).to receive(:completed!)
        service.call
      end

      context "when there are no unpaid bills" do
        before { allow(unpaid_bills).to receive(:update_all).and_return(0) }

        it "marks the payment as failed" do
          begin
            service.call
          rescue StandardError
            nil
          end
          expect(payment).to have_received(:failed!)
        end

        it "raises an error" do
          expect { service.call }.to raise_error(StandardError)
        end
      end
    end

    context "when payable_type is unknown" do
      before { allow(payment).to receive(:payable_type).and_return("Unknown") }

      it "marks the payment as failed" do
        begin
          service.call
        rescue InvalidPaymentType
          nil
        end
        expect(payment).to have_received(:failed!)
      end

      it "raises InvalidPaymentType" do
        expect { service.call }.to raise_error(InvalidPaymentType)
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(payment).to receive(:payable_type).and_raise(StandardError, "unexpected")
        allow(Sentry).to receive(:capture_exception)
      end

      it "marks the payment as failed" do
        begin
          service.call
        rescue StandardError
          nil
        end
        expect(payment).to have_received(:failed!)
      end

      it "reports the exception to Sentry" do
        begin
          service.call
        rescue StandardError
          nil
        end
        expect(Sentry).to have_received(:capture_exception).with(
          instance_of(StandardError),
          extra: {payment_id: payment.id}
        )
      end

      it "re-raises the error" do
        expect { service.call }.to raise_error(StandardError, "unexpected")
      end
    end
  end
end
