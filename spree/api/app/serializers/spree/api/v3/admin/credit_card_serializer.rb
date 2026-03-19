module Spree
  module Api
    module V3
      module Admin
        class CreditCardSerializer < V3::CreditCardSerializer
          typelize customer_id: [:string, nullable: true],
                   payment_method_id: [:string, nullable: true],
                   gateway_payment_profile_id: [:string, nullable: true]

          attributes :gateway_payment_profile_id

          attribute :customer_id do |credit_card|
            credit_card.user&.prefixed_id
          end

          attribute :payment_method_id do |credit_card|
            credit_card.payment_method&.prefixed_id
          end

          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
