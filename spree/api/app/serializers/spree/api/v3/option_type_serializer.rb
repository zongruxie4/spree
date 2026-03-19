module Spree
  module Api
    module V3
      class OptionTypeSerializer < BaseSerializer
        typelize name: :string, label: :string, position: :number

        attributes :name, :label, :position
      end
    end
  end
end
