module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Post-purchase order data (completed orders)
      class OrderSerializer < BaseSerializer
        typelize number: :string, email: :string,
                 special_instructions: [:string, nullable: true], currency: :string, locale: [:string, nullable: true], item_count: :number,
                 fulfillment_status: [:string, nullable: true], payment_status: [:string, nullable: true],
                 item_total: :string, display_item_total: :string,
                 delivery_total: :string, display_delivery_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 promo_total: :string, display_promo_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 total: :string, display_total: :string, completed_at: [:string, nullable: true],
                 bill_address: { nullable: true }, ship_address: { nullable: true }

        attributes :number, :email, :special_instructions,
                   :currency, :locale, :item_count,
                   :item_total, :display_item_total,
                   :adjustment_total, :display_adjustment_total, :promo_total, :display_promo_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :fulfillment_status do |order|
          order.shipment_state
        end

        attribute :payment_status do |order|
          order.payment_state
        end

        attribute :delivery_total do |order|
          order.ship_total
        end

        attribute :display_delivery_total do |order|
          order.display_ship_total.to_s
        end

        many :order_promotions, key: :promotions, resource: Spree.api.order_promotion_serializer
        many :line_items, key: :items, resource: Spree.api.line_item_serializer
        many :shipments, key: :fulfillments, resource: Spree.api.fulfillment_serializer
        many :payments, resource: Spree.api.payment_serializer
        one :bill_address, resource: Spree.api.address_serializer
        one :ship_address, resource: Spree.api.address_serializer
      end
    end
  end
end
