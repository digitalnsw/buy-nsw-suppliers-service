module SellerService
  class EligibilityForm < SellerService::AuditableForm
    field :govdc
    field :offers_cloud
    field :offers_ict

    validates :govdc, inclusion: { in: [false, true, 'false', 'true'] }
    validates :offers_cloud, inclusion: { in: [false, true, 'false', 'true'] }
    validates :offers_ict, inclusion: { in: [false, true, 'false', 'true'] }
    validate :eligibile

    def eligibile
      if govdc.to_s != 'true' && offers_ict.to_s != 'true' && offers_cloud.to_s != 'true'
        errors.add(:govdc, "To become an eligible supplier on buy.nsw you have to offer one of the above")
      end
    end
  end
end
