module Spree
  module Api
    module V3
      module Admin
        class PaymentSourceSerializer < V3::PaymentSourceSerializer
          typelize gateway_payment_profile_id: [:string, nullable: true]

          attribute :gateway_payment_profile_id do |source|
            source.try(:gateway_payment_profile_id)
          end
        end
      end
    end
  end
end
