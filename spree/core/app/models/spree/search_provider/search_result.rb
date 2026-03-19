module Spree
  module SearchProvider
    SearchResult = Struct.new(:products, :filters, :sort_options, :default_sort, :total_count, :pagy, keyword_init: true)
  end
end
