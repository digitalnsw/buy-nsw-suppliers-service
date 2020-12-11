module SellerService::Account
  class BusinessNameAndAbnForm < SellerService::Account::AuditableForm
    field :name
    field :abn, usage: :read_only
    field :establishment_date, type: :date
    field :seller_id, usage: :back_end

    validates_presence_of :name
    validates :name, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,100}\z/ }

    def seller
      SellerService::Seller.find(seller_id)
    end

    validates_presence_of :establishment_date
    validate :establishment_date_in_the_past
    def establishment_date_in_the_past
      if establishment_date.present? && establishment_date > Date.today
        errors.add(:establishment_date, "Establishment date can not be later than today")
      end
    end
  end
end
