module Spree
  module Api
    module V3
      class FulfillmentSerializer < BaseSerializer
        typelize number: :string, status: :string, fulfillment_type: :string,
                 tracking: [:string, nullable: true],
                 tracking_url: [:string, nullable: true], fulfilled_at: [:string, nullable: true],
                 cost: :string, display_cost: :string

        attributes :number, :tracking, :tracking_url,
                   :cost, :display_cost,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :status do |shipment|
          shipment.state
        end

        attribute :fulfillment_type do |shipment|
          shipment.digital? ? 'digital' : 'shipping'
        end

        attribute :fulfilled_at do |shipment|
          shipment.shipped_at&.iso8601
        end

        one :shipping_method, key: :delivery_method, resource: Spree.api.delivery_method_serializer
        one :stock_location, resource: Spree.api.stock_location_serializer
        many :shipping_rates, key: :delivery_rates, resource: Spree.api.delivery_rate_serializer
      end
    end
  end
end
