module SellerService::Profile
  class ReferenceAndCaseStudyForm < SellerService::BaseForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :references, type: :json
    field :case_studies, type: :json

    validates :references, 'shared_modules/json': { schema:
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

    validates :case_studies, 'shared_modules/json': { schema:
      [
        {
          document_id: 'document',
          description: 'text',
        }
      ]
    }

    def after_load
      self.references ||= []
      self.case_studies ||= []
    end
  end
end
