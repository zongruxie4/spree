require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::ProductPresenter do
    let(:store) { @default_store }
    let(:product) { create(:product, name: 'Test Shirt', stores: [store]) }
    let(:presenter) { described_class.new(product, store) }

    describe '#call' do
      subject(:documents) { presenter.call }

      it 'returns an array of documents' do
        expect(documents).to be_an(Array)
        expect(documents).not_to be_empty
      end

      context 'document structure' do
        subject(:doc) { documents.first }

        it 'includes composite prefixed_id and product_id' do
          expect(doc[:prefixed_id]).to start_with(product.prefixed_id)
          expect(doc[:product_id]).to eq(product.prefixed_id)
        end

        it 'includes locale and currency' do
          expect(doc[:locale]).to be_present
          expect(doc[:currency]).to be_present
        end

        it 'includes flat name and description' do
          expect(doc[:name]).to eq('Test Shirt')
          expect(doc[:slug]).to eq(product.slug)
        end

        it 'includes flat price' do
          expect(doc).to have_key(:price)
        end

        it 'includes stock status' do
          expect(doc).to have_key(:in_stock)
        end

        it 'includes timestamps' do
          expect(doc[:created_at]).to be_present
          expect(doc[:updated_at]).to be_present
        end

        it 'includes category data as prefixed IDs' do
          expect(doc[:category_ids]).to be_an(Array)
        end

        it 'includes option data as prefixed IDs' do
          expect(doc[:option_type_ids]).to be_an(Array)
          expect(doc[:option_value_ids]).to be_an(Array)
        end
      end

      context 'with categories' do
        let(:taxonomy) { create(:taxonomy, store: store) }
        let(:taxon) { create(:taxon, taxonomy: taxonomy) }
        let(:product) { create(:product, name: 'Test Shirt', stores: [store], taxons: [taxon]) }

        it 'indexes category_ids as prefixed IDs' do
          doc = documents.first
          expect(doc[:category_ids]).to eq([taxon.prefixed_id])
          expect(doc[:category_ids].first).to start_with('ctg_')
        end
      end

      context 'with multiple markets' do
        let!(:us_market) { create(:market, store: store, name: 'US', currency: 'USD', default_locale: 'en') }
        let!(:eu_market) { create(:market, store: store, name: 'EU', currency: 'EUR', default_locale: 'de', supported_locales: 'de,fr') }

        # Reload store to pick up new markets
        let(:presenter) { described_class.new(product, store.reload) }

        it 'creates documents for each market × locale combination' do
          locales_currencies = documents.map { |d| [d[:locale], d[:currency]] }
          expect(locales_currencies).to include(['en', 'USD'])
          expect(locales_currencies).to include(['de', 'EUR'])
          expect(locales_currencies).to include(['fr', 'EUR'])
        end

        it 'each document has a unique composite prefixed_id' do
          ids = documents.map { |d| d[:prefixed_id] }
          expect(ids.uniq.size).to eq(ids.size)
        end
      end

      context 'with option values' do
        let(:product) { create(:product_with_option_types, stores: [store]) }

        it 'includes option value prefixed IDs' do
          doc = documents.first
          doc[:option_value_ids].each do |ov_id|
            expect(ov_id).to start_with('optval_')
          end
        end
      end
    end
  end
end
