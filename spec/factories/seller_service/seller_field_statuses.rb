module SellerService
  FactoryBot.define do
    factory :seller_field_status, class: SellerService::SellerFieldStatus do
      field "MyString"
      status "MyString"
      seller ""
    end
  end
end
