module Spree
  module Api
    module V3
      # Store API Order Serializer
      # Post-purchase order data (completed orders)
      class OrderSerializer < BaseSerializer
        typelize number: :string, email: :string,
                 customer_note: [:string, nullable: true], currency: :string, locale: [:string, nullable: true], total_quantity: :number,
                 fulfillment_status: [:string, nullable: true], payment_status: [:string, nullable: true],
                 item_total: :string, display_item_total: :string,
                 delivery_total: :string, display_delivery_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 discount_total: :string, display_discount_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 total: :string, display_total: :string, completed_at: [:string, nullable: true],
                 billing_address: { nullable: true }, shipping_address: { nullable: true }

        attributes :number, :email, :customer_note,
                   :currency, :locale, :total_quantity,
                   :item_total, :display_item_total,
                   :adjustment_total, :display_adjustment_total,
                   :discount_total, :display_discount_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   :delivery_total, :display_delivery_total, :fulfillment_status, :payment_status,
                   completed_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        many :discounts, resource: Spree.api.discount_serializer
        many :line_items, key: :items, resource: Spree.api.line_item_serializer
        many :fulfillments, resource: Spree.api.fulfillment_serializer
        many :payments, resource: Spree.api.payment_serializer
        one :billing_address, resource: Spree.api.address_serializer
        one :shipping_address, resource: Spree.api.address_serializer
      end
    end
  end
end
