require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::Database do
    let(:store) { @default_store }
    let(:provider) { described_class.new(store) }

    let!(:product_1) { create(:product, name: 'Blue Shirt', stores: [store]) }
    let!(:product_2) { create(:product, name: 'Red Pants', stores: [store]) }
    let!(:product_3) { create(:product, name: 'Blue Jacket', stores: [store]) }

    describe '#search_and_filter' do
      let(:scope) { store.products }

      context 'with text search' do
        subject(:result) { provider.search_and_filter(scope: scope, query: 'blue') }

        it 'returns matching products' do
          expect(result.products).to include(product_1, product_3)
          expect(result.products).not_to include(product_2)
        end

        it 'returns a SearchResult' do
          expect(result).to be_a(SearchProvider::SearchResult)
        end

        it 'returns total count' do
          expect(result.total_count).to eq(2)
        end

        it 'returns sort options as objects' do
          expect(result.sort_options).to be_an(Array)
          ids = result.sort_options.map { |o| o[:id] }
          expect(ids).to include('price', '-price', 'best_selling')
        end
      end

      context 'without search query' do
        subject(:result) { provider.search_and_filter(scope: scope) }

        it 'returns all products' do
          expect(result.products).to include(product_1, product_2, product_3)
        end

        it 'returns correct total count' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with blank query' do
        subject(:result) { provider.search_and_filter(scope: scope, query: '') }

        it 'returns all products' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with pagination' do
        subject(:result) { provider.search_and_filter(scope: scope, page: 1, limit: 2) }

        it 'limits results' do
          expect(result.products.length).to eq(2)
        end

        it 'returns full total count' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with page 2' do
        subject(:result) { provider.search_and_filter(scope: scope, page: 2, limit: 2) }

        it 'offsets results' do
          expect(result.products.length).to eq(1)
        end
      end

      context 'with sorting' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'name') }

        it 'sorts by name ascending' do
          names = result.products.map(&:name)
          expect(names).to eq(names.sort)
        end
      end

      context 'with descending sort' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: '-name') }

        it 'sorts by name descending' do
          names = result.products.map(&:name)
          expect(names).to eq(names.sort.reverse)
        end
      end

      context 'with custom price sort' do
        subject(:result) { provider.search_and_filter(scope: scope, sort: 'price') }

        it 'returns all products' do
          expect(result.total_count).to eq(3)
        end
      end

      context 'with ransack filters' do
        subject(:result) { provider.search_and_filter(scope: scope, filters: { 'name_cont' => 'Shirt' }) }

        it 'filters by ransack params' do
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end
      end

      context 'with search and filters combined' do
        subject(:result) { provider.search_and_filter(scope: scope, query: 'blue', filters: { 'name_cont' => 'Shirt' }) }

        it 'applies both search and filters' do
          expect(result.products).to include(product_1)
          expect(result.products).not_to include(product_2, product_3)
        end
      end
    end

    describe '#index' do
      it 'is a no-op' do
        expect { provider.index(product_1) }.not_to raise_error
      end
    end

    describe '#remove' do
      it 'is a no-op' do
        expect { provider.remove(product_1) }.not_to raise_error
      end
    end

    describe '#remove_by_id' do
      it 'is a no-op' do
        expect { provider.remove_by_id(product_1.id) }.not_to raise_error
      end
    end

    describe '#reindex' do
      it 'is a no-op' do
        expect { provider.reindex(store.products) }.not_to raise_error
      end
    end
  end
end
