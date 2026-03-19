module Spree
  module SearchProvider
    class ProductPresenter
      attr_reader :product, :store

      def initialize(product, store)
        @product = product
        @store = store
      end

      # Returns an array of documents — one per market × locale combination.
      # Each document has flat name, description, price fields (no dynamic suffixes).
      def call
        documents = []

        market_locale_pairs.each do |market, locale|
          Mobility.with_locale(locale) do
            documents << build_document(locale, market.currency)
          end
        end

        # Fallback: if no markets, index with store defaults
        if documents.empty?
          documents << build_document(store.default_locale || I18n.default_locale.to_s, store.default_currency)
        end

        documents
      end

      private

      def build_document(locale, currency)
        price = lowest_price(currency)

        {
          # Composite ID: product + locale + currency
          prefixed_id: "#{product.prefixed_id}_#{locale}_#{currency}",
          product_id: product.prefixed_id,
          locale: locale.to_s,
          currency: currency,
          # Translated fields (Mobility resolves via current locale)
          name: product.name,
          description: product.description,
          slug: product.slug,
          # Price in this currency
          price: price&.to_f,
          compare_at_price: compare_at_price(currency)&.to_f,
          # Non-locale/currency fields
          status: product.status,
          sku: product.sku,
          in_stock: product.in_stock?,
          store_ids: product.store_ids.map(&:to_s),
          discontinue_on: product.discontinue_on&.to_i || 0,
          category_ids: product.taxons.map(&:prefixed_id),
          category_names: product.taxons.pluck(:name),
          option_type_ids: product.option_types.map(&:prefixed_id),
          option_type_names: product.option_types.pluck(:presentation),
          option_value_ids: variant_option_value_ids,
          option_values: variant_option_value_presentations,
          tags: product.tag_list || [],
          thumbnail_url: product.primary_media&.url(:large),
          units_sold_count: product.store_products.find_by(store: store)&.units_sold_count || 0,
          available_on: product.available_on&.iso8601,
          created_at: product.created_at&.iso8601,
          updated_at: product.updated_at&.iso8601
        }
      end

      # Returns all market × locale pairs for this store
      def market_locale_pairs
        @market_locale_pairs ||= store.markets.flat_map do |market|
          market.supported_locales_list.map { |locale| [market, locale] }
        end
      end

      def lowest_price(currency)
        product.price_in(currency)&.amount
      end

      def compare_at_price(currency)
        product.compare_at_amount_in(currency)
      end

      def variant_option_value_ids
        variant_option_values_data.map(&:prefixed_id).uniq
      end

      def variant_option_value_presentations
        variant_option_values_data.map(&:presentation).uniq
      end

      def variant_option_values_data
        @variant_option_values_data ||= product.variants.includes(:option_values).flat_map(&:option_values)
      end
    end
  end
end
