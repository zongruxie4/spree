module Spree
  module Api
    module V3
      # Store API Cart Serializer
      # Pre-purchase cart data with checkout progression info
      class CartSerializer < BaseSerializer
        typelize number: :string, current_step: :string, completed_steps: 'string[]', token: :string, email: [:string, nullable: true],
                 customer_note: [:string, nullable: true], currency: :string, locale: [:string, nullable: true], total_quantity: :number,
                 requirements: 'Array<{step: string, field: string, message: string}>',
                 item_total: :string, display_item_total: :string,
                 delivery_total: :string, display_delivery_total: :string,
                 adjustment_total: :string, display_adjustment_total: :string,
                 discount_total: :string, display_discount_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 total: :string, display_total: :string,
                 shipping_eq_billing_address: :boolean,
                 billing_address: { nullable: true }, shipping_address: { nullable: true }

        # Override ID to use cart_ prefix
        attribute :id do |order|
          "cart_#{Spree::PrefixedId::SQIDS.encode([order.id])}"
        end

        attributes :number, :token, :email, :customer_note,
                   :currency, :locale, :total_quantity,
                   :item_total, :display_item_total,
                   :adjustment_total, :display_adjustment_total,
                   :discount_total, :display_discount_total,
                   :tax_total, :display_tax_total, :included_tax_total, :display_included_tax_total,
                   :additional_tax_total, :display_additional_tax_total, :total, :display_total,
                   :delivery_total, :display_delivery_total,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :current_step do |order|
          order.current_checkout_step
        end

        attribute :completed_steps do |order|
          order.completed_checkout_steps
        end

        attribute :requirements do |order|
          Spree::Checkout::Requirements.new(order).call
        end

        attribute :shipping_eq_billing_address do |order|
          order.shipping_eq_billing_address?
        end

        many :discounts, resource: Spree.api.discount_serializer
        many :line_items, key: :items, resource: Spree.api.line_item_serializer
        many :fulfillments, resource: Spree.api.fulfillment_serializer
        many :payments, resource: Spree.api.payment_serializer
        one :billing_address, resource: Spree.api.address_serializer
        one :shipping_address, resource: Spree.api.address_serializer

        many :payment_methods, resource: Spree.api.payment_method_serializer
      end
    end
  end
end
