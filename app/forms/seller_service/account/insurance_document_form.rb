module SellerService::Account
  class InsuranceDocumentForm < SellerService::Account::AuditableForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :professional_indemnity_certificate_ids, type: :json
    field :product_liability_certificate_ids, type: :json
    field :workers_compensation_certificate_ids, type: :json

    field :professional_indemnity_certificate_expiry, type: :date
    field :product_liability_certificate_expiry, type: :date
    field :workers_compensation_certificate_expiry, type: :date

    #TODO: Validate documents expiry times are not past
    validates :professional_indemnity_certificate_expiry, presence: true, if: -> { professional_indemnity_certificate_ids.present? }
    validates :product_liability_certificate_expiry, presence: true, if: -> { product_liability_certificate_ids.present? }
    validates :workers_compensation_certificate_expiry, presence: true, if: -> { workers_compensation_certificate_ids.present? }
    validate :expiry_dates_not_passed

    def expiry_dates_not_passed
      errors.add(:product_liability_certificate_expiry, "Expiry date passed") if product_liability_certificate_expiry.present? && product_liability_certificate_expiry < Date.today
      errors.add(:professional_indemnity_certificate_expiry, "Expiry date passed") if professional_indemnity_certificate_expiry.present? && professional_indemnity_certificate_expiry < Date.today
      errors.add(:workers_compensation_certificate_expiry, "Expiry date passed") if workers_compensation_certificate_expiry.present? && workers_compensation_certificate_expiry < Date.today
    end

    validates :professional_indemnity_certificate_ids, 'seller_service/json': { schema: ['document'] }
    validates :product_liability_certificate_ids, 'seller_service/json': { schema: ['document'] }
    validates :workers_compensation_certificate_ids, 'seller_service/json': { schema: ['document'] }

    def after_load
      self.professional_indemnity_certificate_ids ||= []
      self.product_liability_certificate_ids ||= []
      self.workers_compensation_certificate_ids ||= []
    end

    def before_save
      self.professional_indemnity_certificate_expiry = nil if professional_indemnity_certificate_ids.blank?
      self.product_liability_certificate_expiry = nil if product_liability_certificate_ids.blank?
      self.workers_compensation_certificate_expiry = nil if workers_compensation_certificate_ids.blank?
    end
  end
end
