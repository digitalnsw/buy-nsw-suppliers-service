module SellerService
  class SellerFieldStatus < SellerService::ApplicationRecord
    self.table_name = 'seller_field_statuses'
    belongs_to :seller, class_name: "SellerService::Seller", inverse_of: :seller_field_statuses

  end
end
