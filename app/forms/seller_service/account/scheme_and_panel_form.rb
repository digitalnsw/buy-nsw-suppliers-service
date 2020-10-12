module SellerService::Account
  class SchemeAndPanelForm < SellerService::Account::AuditableForm
    field :schemes_and_panels, type: :json, usage: :read_only
    field :all_schemes, type: :json, usage: :front_end

    def after_load
      self.all_schemes = SellerService::SupplierScheme.all.map(&:serialized)
    end
  end
end
