module SellerService::Profile
  class AccreditationAndLicenseForm < SellerService::BaseForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :accreditations, type: :json
    field :accreditation_document_ids, type: :json
    field :licenses, type: :json
    field :license_document_ids, type: :json

    validates :accreditations, 'shared_modules/json': { schema: ['limited?'] }
    validates :accreditation_document_ids, 'shared_modules/json': { schema: ['document'] }
    validates :licenses, 'shared_modules/json': { schema: ['limited?'] }
    validates :license_document_ids, 'shared_modules/json': { schema: ['document'] }

    def after_load
      self.accreditations ||= []
      self.accreditation_document_ids ||= []
      self.licenses ||= []
      self.license_document_ids ||= []
    end

    def before_validate
      before_save
    end

    def before_save
      accreditations.select!(&:present?) if accreditations.present?
      licenses.select!(&:present?) if licenses.present?
    end
  end
end
