module SellerService::Account
  class BusinessCategoryForm < SellerService::Account::AuditableForm
    field :start_up
    field :sme
    field :not_for_profit
    field :australian_owned
    field :indigenous
    field :disability

    field :corporate_structure, usage: :back_end
    field :establishment_date, usage: :back_end
    field :number_of_employees, usage: :read_only

    field :can_be_startup, usage: :front_end
    field :overseas, usage: :front_end
    field :sub_categories, type: :json, usage: :front_end

    field :services, type: :json
    validates_presence_of :services
    validates :services, 'shared_modules/json': { schema: [
      Set.new(SellerService::SellerVersion.all_services)
    ] }

    def establishment_date_in_range
      establishment_date.present? && establishment_date > 5.years.ago
    end

    def level_1_services
      self.services ||= []
      @level_1_services ||= services.to_a & SellerService::SellerVersion.level_1_services
    end

    def level_2_services
      self.services ||= []
      @level_2_services ||= seller.draft_version.level_2_services
      # @level_2_services ||= services.to_a & SellerService::SellerVersion.level_2_services
    end

    def level_3_services
      self.services ||= []
      @level_3_services ||= seller.draft_version.level_3_services
      # @level_3_services ||= services.to_a & SellerService::SellerVersion.level_3_services
    end

    def after_load
      self.sub_categories = SellerService::SellerVersion.flat_sub_categories
      self.can_be_startup = establishment_date_in_range
      self.overseas = corporate_structure == 'overseas'
      self.start_up = false unless establishment_date_in_range
      self.sme = false if number_of_employees == '200plus' || overseas
    end

    def before_save
      self.overseas = corporate_structure == 'overseas'
      self.sme = false if number_of_employees == '200plus' || overseas
      self.start_up = false unless establishment_date_in_range

      self.services = level_1_services + level_2_services + level_3_services
    end
  end
end
