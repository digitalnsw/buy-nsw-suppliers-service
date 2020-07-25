module SellerService::Account
  class FinancialDocumentForm < SellerService::Account::AuditableForm
    field :seller_id, usage: :back_end # this is needed for the security check in docuemnt attachment
    field :financial_statement_ids, type: :json

    field :financial_statement_expiry, type: :date, usage: :back_end, feedback: false
    field :financial_statement_confirmed, usage: :front_end, feedback: false

    #TODO: Validate the financial_statement_expiry is not past
    validates :financial_statement_expiry, presence: true, if: -> { financial_statement_ids.present? }
    validates :financial_statement_ids, 'seller_service/json': { schema: ['document'] }

    def after_load
      self.financial_statement_ids ||= []
      self.financial_statement_confirmed = (
        financial_statement_expiry.present? &&
        financial_statement_expiry > Date.today
      )
    end

    def before_validate
      before_save
    end

    def before_save
      self.financial_statement_confirmed = nil if financial_statement_ids.blank?
      if financial_statement_confirmed
        self.financial_statement_expiry = 1.year.from_now
      else
        self.financial_statement_expiry = nil
      end
    end
  end
end
