namespace :spree do
  namespace :search do
    desc 'Reindex all products in the search provider'
    task reindex: :environment do
      Spree::Store.all.find_each do |store|
        provider = Spree.search_provider.constantize.new(store)
        total = store.products.count

        puts "Reindexing #{store.name} (#{total} products)..."

        # Configure index settings (filterable, sortable, searchable attributes)
        provider.ensure_index_settings! if provider.respond_to?(:ensure_index_settings!)

        indexed = 0
        store.products.reorder(id: :asc)
             .preload(:taxons, :option_types, :primary_media,
                      variants_including_master: [:prices, :option_values])
             .find_in_batches(batch_size: 500) do |batch|
          documents = batch.flat_map { |product| Spree::SearchProvider::ProductPresenter.new(product, store).call }
          provider.index_batch(documents) if provider.respond_to?(:index_batch)
          indexed += batch.size
          print "\r  #{indexed}/#{total} products indexed"
        end

        puts "\nDone."
      end
    end
  end
end
