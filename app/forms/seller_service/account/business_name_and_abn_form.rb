module SellerService::Account
  class BusinessNameAndAbnForm < SellerService::Account::AuditableForm
    field :name
    field :abn
    field :read_abn, usage: :back_end
    field :lock_abn, usage: :front_end
    field :establishment_date, type: :date
    field :seller_id, usage: :back_end
    field :can_join, usage: :front_end

    validates_presence_of :name
    validates :name, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }

    validates_presence_of :abn
    validate :abn_format
    validate :abn_registered
    validate :abn_uniqueness

    def seller
      SellerService::Seller.find(seller_id)
    end

    def after_load
      self.lock_abn = seller.uuid.present?
    end

    def before_save
      self.abn = read_abn if seller.uuid.present?
    end

    def abn_format
      if abn.present? && !ABN.valid?(abn.gsub(/\s+/, ""))
        errors.add(:abn, "ABN is not valid")
      end
    end

    def abn_registered
      if abn.present? && ABN.valid?(abn.gsub(/\s+/, ""))
        r = SharedModules::Abr.lookup abn.gsub(/\s+/, "")
        if r.nil? || r[:status] != 'Active'
          errors.add(:abn, "ABN is not registered")
        end
      end
    end

    def abn_owner
      @abn_owner ||= SellerService::SellerVersion.where.not(seller_id: seller_id).
        where(state: [:pending, :approved], abn: ABN.new(abn).to_s).first
    end

    def pending_join?
      return false if abn_owner.blank?
      return @pending_join if @pending_join != nil
      unifier = 'join_' + session_user.id.to_s + '_to_' + abn_owner.seller_id.to_s
      @pending_join = SharedResources::RemoteNotification.pending_notification?(unifier: unifier)
    end

    def abn_taken?
      abn.present? && ABN.valid?(abn.gsub(/\s+/, "")) && abn_owner.present?
    end

    def can_join?
      abn_taken? && session_user&.seller_ids.exclude?(abn_owner.seller_id)
    end

    def abn_uniqueness
      if abn_taken?
        if pending_join?
          errors.add(:abn, "This ABN is not unique, your request to joing this supplier is pending.")
        else
          errors.add(:abn, "This ABN is not unique, you or someone from your company may have already created an account with us.")
        end
        if can_join? && !pending_join?
          errors.add(:can_join, true)
        end
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
