module Spree
  module SearchProvider
    class ProductPresenter
      attr_reader :product, :store

      def initialize(product, store)
        @product = product
        @store = store
      end

      def call
        {
          prefixed_id: product.prefixed_id,
          name: product.name,
          description: product.description,
          slug: product.slug,
          status: product.status,
          sku: product.sku,
          in_stock: product.in_stock?,
          store_ids: product.store_ids.map(&:to_s),
          currency_codes: product.prices_including_master.base_prices.where.not(amount: nil).pluck(:currency).uniq,
          category_ids: product.taxons.map(&:prefixed_id),
          category_names: product.taxons.pluck(:name),
          option_type_ids: product.option_types.map(&:prefixed_id),
          option_type_names: product.option_types.pluck(:presentation),
          option_value_ids: variant_option_value_ids,
          option_values: variant_option_value_presentations,
          tags: product.tag_list || [],
          thumbnail_url: product.primary_media&.url(:large),
          units_sold_count: product.store_products.find_by(store: store)&.units_sold_count || 0,
          discontinue_on: product.discontinue_on&.to_i || 0,
          available_on: product.available_on&.iso8601,
          created_at: product.created_at&.iso8601,
          updated_at: product.updated_at&.iso8601,
          # Multi-currency prices
          **prices_by_currency,
          # Multi-language translations
          **translations_by_locale
        }
      end

      private

      # Indexes base prices (no price list overrides) for all currencies:
      # { price_USD: 19.99, price_EUR: 17.50, compare_at_price_USD: 24.99 }
      def prices_by_currency
        result = {}

        product.prices_including_master.base_prices.where.not(amount: nil).each do |price|
          currency = price.currency
          amount = price.amount.to_f

          # Keep the lowest price per currency across all variants
          key = "price_#{currency}"
          if result[key].nil? || amount < result[key]
            result[key] = amount
          end

          if price.compare_at_amount.present?
            result["compare_at_price_#{currency}"] = price.compare_at_amount.to_f
          end
        end

        result
      end

      # Indexes translations for all locales: { name_en: "Shirt", name_fr: "Chemise", description_en: "...", ... }
      def translations_by_locale
        result = {}

        if product.respond_to?(:translations)
          product.translations.each do |translation|
            locale = translation.locale
            result["name_#{locale}"] = translation.name if translation.name.present?
            result["description_#{locale}"] = translation.description if translation.description.present?
            result["slug_#{locale}"] = translation.slug if translation.slug.present?
          end
        end

        # Ensure current locale is always indexed
        result["name_#{I18n.locale}"] ||= product.name
        result["description_#{I18n.locale}"] ||= product.description
        result["slug_#{I18n.locale}"] ||= product.slug

        result
      end

      def variant_option_value_ids
        variant_option_values_data.map { |ov| ov.prefixed_id }.uniq
      end

      def variant_option_value_presentations
        variant_option_values_data.map { |ov| ov.presentation }.uniq
      end

      def variant_option_values_data
        @variant_option_values_data ||= product.variants.includes(:option_values).flat_map { |v| v.option_values }
      end
    end
  end
end
