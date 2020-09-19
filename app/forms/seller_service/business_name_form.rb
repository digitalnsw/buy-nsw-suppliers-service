module SellerService
  class BusinessNameForm < SellerService::AuditableForm
    field :name
    field :abn
    field :establishment_date, type: :date
    field :seller_id, usage: :back_end
    field :can_join, usage: :front_end

    validates_presence_of :name
    validates :name, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }

    validates_presence_of :abn
    validate :abn_format
    validate :abn_uniqueness

    def abn_format
      if abn.present? && !ABN.valid?(abn.gsub(/\s+/, ""))
        errors.add(:abn, "ABN is not valid")
      end
    end

    def abn_taken?
      abn.present? && ABN.valid?(abn.gsub(/\s+/, "")) &&
        SellerService::SellerVersion.where.not(seller_id: seller_id).
        where(state: [:pending, :approved], abn: ABN.new(abn).to_s).exists?
    end

    def can_join?
      abn.present? && ABN.valid?(abn.gsub(/\s+/, "")) &&
        SellerService::SellerVersion.where.not(seller_id: session_user&.seller_ids).
        where(state: [:pending, :approved], abn: ABN.new(abn).to_s).exists?
    end

    def abn_uniqueness
      if abn_taken?
        errors.add(:abn, "This ABN is not unique, you or someone from your company may have already created an account with us.")
      end
      if can_join?
        errors.add(:can_join, true)
      end
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
