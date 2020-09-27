module SellerService::Profile
  class CompanyDescriptionForm < SellerService::BaseForm
    field :summary

    validates :summary, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
  end
end
