module SellerService
  class SellerAddress < OpenStruct
    # NOTE: This object represents a seller address, which is persisted as an
    # array of JSON objects on the SellerVersion model.
    #
    # This object remains useful for serialization, enumerizing the `state`
    # field, and building forms for addresses.
    #
    extend ActiveModel::Naming
    extend Enumerize
    extend Forwardable

    FIELDS = [:address, :address_2, :address_3, :suburb, :postcode, :country].freeze

    enumerize :state, in: [:nsw, :act, :nt, :qld, :sa, :tas, :vic, :wa, :outside_au]

    def initialize(attributes = {})
      attributes.symbolize_keys! if attributes.is_a?(Hash)

      # NOTE: As we have defined the `state` field in enumerize, we need to
      # directly set the value of the field as it does not infer it from the
      # OpenStruct table
      #
      self.state = attributes[:state]

      super(attributes.slice(*FIELDS))
    end

    def to_h
      super.merge(state: state)
    end

    # NOTE: The following methods serve no purpose but to maintain compatibility
    # with building form objects.
    #
    def id
      nil
    end

    def persisted?
      true
    end
  end
end
