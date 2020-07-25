module SellerService
  FactoryBot.define do
    factory :seller_address, class: SellerService::SellerAddress do
      address '123 Test Street'
      address_2 ''
      address_3 ''
      suburb 'Sydney'
      state 'nsw'
      postcode '2000'
      country 'AU'

      initialize_with { new(attributes) }
    end
  end
end
