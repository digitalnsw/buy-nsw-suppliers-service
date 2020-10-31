module SellerService::Account
  class SchemeAndPanelForm < SellerService::Account::AuditableForm
    field :schemes, type: :json, usage: :read_only

    def after_load
      self.schemes = schemes.current.map(&:serialized)
    end
  end
end
