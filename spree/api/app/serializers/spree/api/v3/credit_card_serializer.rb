module Spree
  module Api
    module V3
      class CreditCardSerializer < BaseSerializer
        typelize brand: :string, last4: :string, month: :number, year: :number,
                 name: [:string, nullable: true], default: :boolean

        attributes :brand, :last4, :month, :year, :name, :default
      end
    end
  end
end
