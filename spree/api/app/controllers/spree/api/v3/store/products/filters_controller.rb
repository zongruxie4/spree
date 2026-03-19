module Spree
  module Api
    module V3
      module Store
        module Products
          class FiltersController < Store::BaseController
            include Spree::Api::V3::Store::SearchProviderSupport

            def index
              result = search_provider.search_and_filter(
                scope: filters_scope,
                query: search_query,
                filters: (search_filters || {}).merge('_category' => category),
                page: 1,
                limit: 0
              )

              render json: {
                filters: result.filters,
                sort_options: result.sort_options,
                default_sort: result.default_sort,
                total_count: result.total_count
              }
            end

            private

            def filters_scope
              scope = current_store.products.active(current_currency)
              scope = scope.in_category(category) if category.present?
              scope.accessible_by(current_ability, :show)
            end

            def category
              category_id = params[:category_id]
              @category ||= category_id.present? ? current_store.categories.find_by_param(category_id) : nil
            end
          end
        end
      end
    end
  end
end
