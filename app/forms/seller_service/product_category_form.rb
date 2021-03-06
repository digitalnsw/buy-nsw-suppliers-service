module SellerService
  class ProductCategoryForm < SellerService::AuditableForm
    field :services, type: :json
    validates_presence_of :services
    validates :services, 'shared_modules/json': { schema: [
      Set.new(SellerService::SellerVersion.all_services)
    ] }

    field :top_categories, type: :json, usage: :front_end
    field :sub_categories, type: :json, usage: :front_end

    def after_load
      self.top_categories = SellerService::SellerVersion.service_levels.keys.map{|k| {key: k, value: k, label: :friendly} }
      self.sub_categories = SellerService::SellerVersion.flat_sub_categories
    end

    def before_save
      self.services &= SellerService::SellerVersion.break_levels(services).flatten
    end
  end
end
