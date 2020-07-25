module SellerService::Profile
  class GovernmentCredentialForm < SellerService::BaseForm
    field :government_credentials, type: :json

    validates :government_credentials, 'seller_service/json': { schema:
      [
        {
          first_name: 'name',
          last_name: 'name',
          role: 'limited?',
          provided_services: 'limited',
          phone: 'phone?',
          email: 'email?',
          project_description: 'text?',
        }
      ]
    }

    def after_load
      self.government_credentials ||= []
    end
  end
end
