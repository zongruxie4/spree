module Spree
  module Api
    module V3
      module Admin
        class DeliveryRateSerializer < V3::DeliveryRateSerializer
          one :shipping_method, key: :delivery_method, resource: Spree.api.admin_delivery_method_serializer, if: proc { expand?('delivery_method') }
        end
      end
    end
  end
end
