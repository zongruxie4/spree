module Spree
  module SearchProvider
    class Meilisearch < Base
      PREFIXED_ID_PATTERN = /\A[a-z]+_[A-Za-z0-9]+\z/
      ALLOWED_STATUSES = %w[active draft archived paused].freeze

      def self.indexing_required?
        true
      end

      def initialize(store)
        super
        require 'meilisearch'
      rescue LoadError
        raise LoadError, "Add `gem 'meilisearch'` to your Gemfile to use the Meilisearch search provider"
      end

      def search_and_filter(scope:, query: nil, filters: {}, sort: nil, page: 1, limit: 25)
        page = [page.to_i, 1].max
        limit = limit.to_i.clamp(1, 100)

        search_params = {
          filter: build_filters(filters),
          facets: facet_attributes,
          sort: build_sort(sort),
          offset: (page - 1) * limit,
          limit: limit
        }

        Rails.logger.debug { "[Meilisearch] index=#{index_name} query=#{query.inspect} #{search_params.compact.inspect}" }

        begin
          ms_result = client.index(index_name).search(query.to_s, search_params)
        rescue ::Meilisearch::ApiError => e
          Rails.logger.warn { "[Meilisearch] Search failed: #{e.message}. Run `rake spree:search:reindex` to initialize the index." }
          Rails.error.report(e, handled: true, context: { index: index_name, query: query })
          return empty_result(scope, page, limit)
        end

        Rails.logger.debug { "[Meilisearch] #{ms_result['estimatedTotalHits']} hits in #{ms_result['processingTimeMs']}ms" }

        # Hits have composite prefixed_id (prod_abc_en_USD), extract product_id (prod_abc)
        product_prefixed_ids = ms_result['hits'].map { |h| h['product_id'] }.uniq
        raw_ids = product_prefixed_ids.filter_map { |pid| Spree::Product.decode_prefixed_id(pid) }

        # Intersect with AR scope for security/visibility.
        # Since we filter by store/status/currency/discontinue_on in Meilisearch,
        # the AR scope is a safety net — it should not filter anything out.
        products = if raw_ids.any?
                     scope.where(id: raw_ids).reorder(nil)
                   else
                     scope.none
                   end

        # Build Pagy object from Meilisearch response (passive mode)
        pagy = build_pagy(ms_result, page, limit)

        SearchResult.new(
          products: products,
          filters: build_facet_response(ms_result['facetDistribution'] || {}),
          sort_options: available_sort_options.map { |id| { id: id } },
          default_sort: 'manual',
          total_count: ms_result['estimatedTotalHits'] || 0,
          pagy: pagy
        )
      end

      def index(product)
        documents = ProductPresenter.new(product, store).call
        client.index(index_name).add_documents(documents, 'prefixed_id')
      end

      def remove(product)
        remove_by_id(product.prefixed_id)
      end

      def index_batch(documents)
        client.index(index_name).add_documents(documents, 'prefixed_id')
      end

      # Remove all documents for a product by its prefixed_id (e.g. 'prod_abc')
      def remove_by_id(prefixed_id)
        filter = "product_id = '#{sanitize_prefixed_id(prefixed_id)}'"
        client.index(index_name).delete_documents(filter: filter)
      rescue ::Meilisearch::ApiError => e
        raise unless e.http_code == 404
      end

      def reindex(scope = nil)
        scope ||= store.products
        ensure_index_settings!

        scope.reorder(id: :asc)
             .preload(*ProductPresenter::REQUIRED_PRELOADS)
             .find_in_batches(batch_size: 500) do |batch|
          documents = batch.flat_map { |product| ProductPresenter.new(product, store).call }
          index_batch(documents)
        end
      end

      # Configure index settings for filtering, sorting, and faceting.
      # Called automatically by reindex, but can be called separately.
      def ensure_index_settings!
        index = client.index(index_name)
        index.update_filterable_attributes(filterable_attributes)
        index.update_sortable_attributes(sortable_attributes)
        index.update_searchable_attributes(searchable_attributes)
      end

      private

      def client
        @client ||= ::Meilisearch::Client.new(
          ENV.fetch('MEILISEARCH_URL', 'http://localhost:7700'),
          ENV['MEILISEARCH_API_KEY']
        )
      end

      def index_name
        "#{store.code}_products"
      end

      def searchable_attributes
        %w[name description sku option_values category_names tags]
      end

      def filterable_attributes
        %w[product_id status in_stock store_ids locale currency discontinue_on price category_ids tags option_value_ids]
      end

      def sortable_attributes
        %w[name price created_at available_on units_sold_count]
      end

      def facet_attributes
        filterable_attributes
      end

      def available_sort_options
        %w[price -price name -name -available_on available_on best_selling]
      end

      # Convert Ransack-style filters to Meilisearch filter syntax.
      # Always applies store scoping, active status, and currency availability
      # so that Meilisearch results match what the AR scope would return.
      # All values are sanitized to prevent filter injection.
      def build_filters(filters)
        conditions = []

        # Always scope to current store, locale, currency, active, not discontinued.
        # This mirrors the AR scope: store.products.active(currency) with locale
        conditions << "store_ids = '#{store.id}'"
        conditions << "status = 'active'"
        conditions << "locale = '#{locale.to_s.gsub(/[^a-zA-Z_-]/, '')}'"
        conditions << "currency = '#{currency.to_s.gsub(/[^A-Z]/, '')}'"
        conditions << "(discontinue_on = 0 OR discontinue_on > #{Time.current.to_i})"

        filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
        return conditions if filters.blank?

        filters.each do |key, value|
          next if value.blank?

          key = key.to_s
          case key
          when 'price_gte'
            conditions << "price >= #{value.to_f}"
          when 'price_lte'
            conditions << "price <= #{value.to_f}"
          when 'in_stock'
            conditions << 'in_stock = true' if value.to_s != '0'
          when 'out_of_stock'
            conditions << 'in_stock = false' if value.to_s != '0'
          when 'categories_id_eq'
            conditions << "category_ids = '#{sanitize_prefixed_id(value)}'" if valid_prefixed_id?(value)
          when 'with_option_value_ids'
            Array(value).each do |ov|
              conditions << "option_value_ids = '#{sanitize_prefixed_id(ov)}'" if valid_prefixed_id?(ov)
            end
          end
        end

        conditions
      end

      def build_sort(sort)
        return nil if sort.blank?

        case sort
        when 'price'
          ['price:asc']
        when '-price'
          ['price:desc']
        when 'name'
          ['name:asc']
        when '-name'
          ['name:desc']
        when '-available_on'
          ['available_on:desc']
        when 'available_on'
          ['available_on:asc']
        when 'best_selling'
          ['units_sold_count:desc']
        end
      end

      # Transform Meilisearch facetDistribution into our standard filter response format
      def build_facet_response(facet_distribution)
        filters = []

        # Price range
        if facet_distribution['price'].present?
          amounts = facet_distribution['price'].keys.map(&:to_f)
          filters << {
            id: 'price',
            type: 'price_range',
            min: amounts.min,
            max: amounts.max,
            currency: currency
          }
        end

        # Availability
        if facet_distribution['in_stock'].present?
          in_stock = facet_distribution['in_stock']['true'] || 0
          out_of_stock = facet_distribution['in_stock']['false'] || 0
          filters << {
            id: 'availability',
            type: 'availability',
            options: [
              { id: 'in_stock', count: in_stock },
              { id: 'out_of_stock', count: out_of_stock }
            ]
          }
        end

        # Option values — group by option type for faceted display
        if facet_distribution['option_value_ids'].present?
          prefixed_ids = facet_distribution['option_value_ids'].keys
          raw_ids = prefixed_ids.filter_map { |pid| Spree::OptionValue.decode_prefixed_id(pid) }
          option_values = Spree::OptionValue.where(id: raw_ids).includes(:option_type).preload_associations_lazily.index_by(&:prefixed_id)

          # Group by option type
          by_option_type = {}
          facet_distribution['option_value_ids'].each do |ov_prefixed_id, count|
            ov = option_values[ov_prefixed_id]
            next unless ov

            ot = ov.option_type
            by_option_type[ot] ||= []
            by_option_type[ot] << { id: ov.prefixed_id, name: ov.name, label: ov.label, position: ov.position, count: count }
          end

          by_option_type.each do |option_type, values|
            filters << {
              id: option_type.prefixed_id,
              type: 'option',
              name: option_type.name,
              label: option_type.label,
              options: values.sort_by { |o| o[:position] }
            }
          end
        end

        # Categories
        if facet_distribution['category_ids'].present?
          prefixed_ids = facet_distribution['category_ids'].keys
          raw_ids = prefixed_ids.filter_map { |pid| Spree::Taxon.decode_prefixed_id(pid) }
          categories = Spree::Taxon.where(id: raw_ids).index_by(&:prefixed_id)

          filters << {
            id: 'categories',
            type: 'category',
            options: facet_distribution['category_ids'].filter_map do |prefixed_id, count|
              cat = categories[prefixed_id]
              next unless cat

              { id: cat.prefixed_id, name: cat.name, permalink: cat.permalink, count: count }
            end
          }
        end

        filters
      end

      def build_pagy(ms_result, page, limit)
        require 'pagy/toolbox/paginators/meilisearch'

        fake_result = Struct.new(:raw_answer).new({
          'totalHits' => ms_result['estimatedTotalHits'] || 0,
          'hitsPerPage' => limit,
          'page' => page
        })

        Pagy::MeilisearchPaginator.paginate(fake_result, {})
      end

      def empty_result(scope, page, limit)
        SearchResult.new(
          products: scope.none,
          filters: [],
          sort_options: available_sort_options.map { |id| { id: id } },
          default_sort: 'manual',
          total_count: 0,
          pagy: Pagy::Offset.new(count: 0, page: page, limit: limit)
        )
      end

      def valid_prefixed_id?(value)
        value.to_s.match?(PREFIXED_ID_PATTERN)
      end

      def sanitize_prefixed_id(value)
        value.to_s.gsub(/[^a-zA-Z0-9_]/, '')
      end
    end
  end
end
