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
      self.top_categories = SellerService::SellerVersion.service_levels.keys.map{|k| {key: k, label: :friendly} }
      self.sub_categories = SellerService::SellerVersion.flat_sub_categories
    end

    def level_1_services
      self.services ||= []
      @level_1_services ||= services.to_a & SellerService::SellerVersion.level_1_services
    end

    def level_2_services
      self.services ||= []
      @level_2_services ||= services.to_a & SellerService::SellerVersion.level_2_services
    end

    def level_3_services
     self.services ||= []
     @level_3_services ||= services.to_a & SellerService::SellerVersion.level_3_services
    end

    def before_save
      self.services = (level_1_services | level_2_services | level_3_services)
    end
  end
end
