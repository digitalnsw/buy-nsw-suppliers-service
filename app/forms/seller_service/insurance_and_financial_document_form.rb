module SellerService
  class InsuranceAndFinancialDocumentForm < SellerService::AuditableForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :professional_indemnity_certificate_ids, type: :json
    field :product_liability_certificate_ids, type: :json
    field :workers_compensation_certificate_ids, type: :json
    field :financial_statement_ids, type: :json

    field :professional_indemnity_certificate_expiry, type: :date
    field :product_liability_certificate_expiry, type: :date
    field :workers_compensation_certificate_expiry, type: :date
    field :financial_statement_expiry, type: :date, usage: :back_end, feedback: false
    field :financial_statement_confirmed, usage: :front_end, feedback: false

    #TODO: The expiry of documents should not be past
    validates :professional_indemnity_certificate_expiry, presence: true, if: -> { professional_indemnity_certificate_ids.present? }
    validates :product_liability_certificate_expiry, presence: true, if: -> { product_liability_certificate_ids.present? }
    validates :workers_compensation_certificate_expiry, presence: true, if: -> { workers_compensation_certificate_ids.present? }
    validate :expiry_dates_not_passed

    def expiry_dates_not_passed
      errors.add(:product_liability_certificate_expiry, "Expiry date passed") if product_liability_certificate_expiry.present? && product_liability_certificate_expiry < Date.today
      errors.add(:professional_indemnity_certificate_expiry, "Expiry date passed") if professional_indemnity_certificate_expiry.present? && professional_indemnity_certificate_expiry < Date.today
      errors.add(:workers_compensation_certificate_expiry, "Expiry date passed") if workers_compensation_certificate_expiry.present? && workers_compensation_certificate_expiry < Date.today
    end
    validates :financial_statement_expiry, presence: true, if: -> { financial_statement_ids.present? }

    validates :professional_indemnity_certificate_ids, 'shared_modules/json': { schema: ['document'] }
    validates :product_liability_certificate_ids, 'shared_modules/json': { schema: ['document'] }
    validates :workers_compensation_certificate_ids, 'shared_modules/json': { schema: ['document'] }
    validates :financial_statement_ids, 'shared_modules/json': { schema: ['document'] }

    def optional?
      true
    end

    def after_load
      self.professional_indemnity_certificate_ids ||= []
      self.product_liability_certificate_ids ||= []
      self.workers_compensation_certificate_ids ||= []
      self.financial_statement_ids ||= []

      self.financial_statement_confirmed = (
        financial_statement_expiry.present? &&
        financial_statement_expiry > Date.today
      )
    end

    def before_save
      self.professional_indemnity_certificate_expiry = nil if professional_indemnity_certificate_ids.blank?
      self.product_liability_certificate_expiry = nil if product_liability_certificate_ids.blank?
      self.workers_compensation_certificate_expiry = nil if workers_compensation_certificate_ids.blank?
      self.financial_statement_confirmed = nil if financial_statement_ids.blank?

      if financial_statement_confirmed
        self.financial_statement_expiry = 1.year.from_now
      else
        self.financial_statement_expiry = nil
      end
    end
  end
end
