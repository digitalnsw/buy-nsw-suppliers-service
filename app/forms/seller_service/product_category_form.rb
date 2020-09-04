module SellerService
  class ProductCategoryForm < SellerService::AuditableForm
    field :services, type: :json
    validates_presence_of :services
    validates :services, 'shared_modules/json': { schema: [
      Set.new(SellerService::SellerVersion.all_services)
    ] }
    # validate :no_more_than_5_level_2_services

    def no_more_than_5_level_2_services
      if level_2_services.size > 5
        errors.add(:services, "You can only select five ICT categories. This is so buyers can find you. Please select the products and services most appealing to buyers.")
      end
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
      @level_3_services ||= services.to_a & SellerService::SellerVersion.service_levels.slice(*level_2_services).values.flatten
    end

    def before_save
      self.services = level_1_services + level_2_services + level_3_services
    end
  end
end
