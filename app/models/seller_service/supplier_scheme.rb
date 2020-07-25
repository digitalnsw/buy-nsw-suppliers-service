module SellerService
  class SupplierScheme < SellerService::ApplicationRecord
    self.table_name = 'supplier_schemes'
    def serialized
      { id: self.id, title: self.title, url: self.url, number: self.number }
    end
  end
end
