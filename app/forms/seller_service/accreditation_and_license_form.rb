module SellerService
  class AccreditationAndLicenseForm < SellerService::AuditableForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :accreditations, type: :json
    field :accreditation_document_ids, type: :json
    field :licenses, type: :json
    field :license_document_ids, type: :json

    validates :accreditations, 'seller_service/json': { schema: ['limited?'] }
    validates :accreditation_document_ids, 'seller_service/json': { schema: ['document'] }
    validates :licenses, 'seller_service/json': { schema: ['limited?'] }
    validates :license_document_ids, 'seller_service/json': { schema: ['document'] }

    validates_presence_of :accreditation_document_ids, if: -> {
      accreditations.present? && accreditations.select(&:present?).present?
    }

    validates_presence_of :license_document_ids, if: -> {
      licenses.present? && licenses.select(&:present?).present?
    }

    def after_load
      self.accreditations ||= []
      self.licenses ||= []
      self.accreditation_document_ids ||= []
      self.license_document_ids ||= []
      while accreditations.size < 2
        accreditations.push ''
      end
      while licenses.size < 2
        licenses.push ''
      end
    end

    def before_validate
      before_save
    end

    def before_save
      accreditations.select!(&:present?) if accreditations.present?
      licenses.select!(&:present?) if licenses.present?
    end

    def optional?
      true
    end
  end
end
