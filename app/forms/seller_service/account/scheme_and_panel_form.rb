module SellerService::Account
  class SchemeAndPanelForm < SellerService::Account::AuditableForm
    field :schemes_and_panels, type: :json
    validates :schemes_and_panels, 'shared_modules/json': { schema: [SellerService::SupplierScheme.all.map(&:id).to_set] }

    field :all_schemes, type: :json, usage: :front_end

    def after_load
      self.all_schemes = SellerService::SupplierScheme.all.map(&:serialized)
    end

    def before_validate
      self.schemes_and_panels = self.schemes_and_panels.map(&:to_i)
      self.schemes_and_panels.uniq!
    end
  end
end
