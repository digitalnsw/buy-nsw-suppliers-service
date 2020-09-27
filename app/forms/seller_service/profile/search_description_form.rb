module SellerService::Profile
  class SearchDescriptionForm < SellerService::BaseForm
    field :flagship_product

    validates :flagship_product, format: { with: /\A[A-Za-z0-9 .'\-_()@&,\/]{0,100}\z/ }
  end
end
