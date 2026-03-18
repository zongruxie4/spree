require 'spec_helper'

module Spree
  RSpec.describe SearchProvider::ProductPresenter do
    let(:store) { @default_store }
    let(:product) { create(:product, name: 'Test Shirt', stores: [store]) }
    let(:presenter) { described_class.new(product, store) }

    describe '#call' do
      subject(:result) { presenter.call }

      it 'returns a hash' do
        expect(result).to be_a(Hash)
      end

      it 'includes core product attributes' do
        expect(result[:prefixed_id]).to eq(product.prefixed_id)
        expect(result[:name]).to eq('Test Shirt')
        expect(result[:slug]).to eq(product.slug)
        expect(result[:status]).to eq(product.status)
        expect(result[:sku]).to eq(product.sku)
      end

      it 'includes timestamps' do
        expect(result[:created_at]).to be_present
        expect(result[:updated_at]).to be_present
      end

      it 'includes stock status' do
        expect(result).to have_key(:in_stock)
      end

      it 'includes category data' do
        expect(result[:category_ids]).to be_an(Array)
        expect(result[:category_names]).to be_an(Array)
      end

      context 'with categories' do
        let(:taxonomy) { create(:taxonomy, store: store) }
        let(:taxon) { create(:taxon, taxonomy: taxonomy) }
        let(:product) { create(:product, name: 'Test Shirt', stores: [store], taxons: [taxon]) }

        it 'indexes category_ids as prefixed IDs' do
          expect(result[:category_ids]).to eq([taxon.prefixed_id])
          expect(result[:category_ids].first).to start_with('ctg_')
        end
      end

      it 'includes option data as prefixed IDs' do
        expect(result[:option_type_ids]).to be_an(Array)
        expect(result[:option_value_ids]).to be_an(Array)
      end

      context 'with prices in multiple currencies' do
        before do
          product.master.prices.find_by(currency: 'USD')&.update!(amount: 19.99)
          create(:price, variant: product.master, amount: 17.50, currency: 'EUR')
        end

        it 'indexes prices for each currency' do
          expect(result['price_USD']).to eq(19.99)
          expect(result['price_EUR']).to eq(17.50)
        end
      end

      context 'with compare_at_price' do
        before do
          product.master.prices.find_by(currency: 'USD')&.update!(amount: 19.99, compare_at_amount: 29.99)
        end

        it 'indexes compare_at_price' do
          expect(result['compare_at_price_USD']).to eq(29.99)
        end
      end

      context 'with translations' do
        it 'indexes translations for the current locale' do
          expect(result["name_#{I18n.locale}"]).to eq('Test Shirt')
        end
      end

      context 'with option values' do
        let(:product) { create(:product_with_option_types, stores: [store]) }

        it 'includes option value prefixed IDs' do
          expect(result[:option_value_ids]).to be_an(Array)
          result[:option_value_ids].each do |ov_id|
            expect(ov_id).to start_with('optval_')
          end
        end
      end
    end
  end
end
