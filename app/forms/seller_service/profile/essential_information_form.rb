module SellerService::Profile
  class EssentialInformationForm < SellerService::BaseForm
    field :flagship_product
    field :summary

    validates :flagship_product, format: { with: /\A[A-Za-z0-9 .'\-_()@&,\/]{0,100}\z/ }
    validates :summary, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
  end
end
