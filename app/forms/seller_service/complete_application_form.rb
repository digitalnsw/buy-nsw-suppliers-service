module SellerService
  class CompleteApplicationForm < SellerService::AuditableForm
    field :agreed_at, type: :date
    field :agreed_by_id, feedback: false

    field :agreed_by_id, usage: :back_end
    field :agreed_at, usage: :back_end
    field :agreed_at_date, usage: :front_end, type: :date
    field :representative_email, usage: :read_only

    field :agreed, usage: :front_end
    field :agreed_by_email, usage: :front_end
    field :representative_user_status, usage: :front_end

    field :agree, usage: :back_end

    def agreed_by
      @agreed_by ||= SharedResources::RemoteUser.get_by_id(agreed_by_id)
    end

    def after_load
      self.agreed = agree.present? && agreed_by_id.present?
      self.agreed_at_date = agreed_at
      self.representative_email.downcase! if representative_email.present?
      if agreed
        if agreed_by
          self.agreed_by_email = agreed_by['email']
        else
          self.agreed = nil
          self.agreed_at_date = nil
        end
      end
      if agreed
        self.representative_user_status = 'agreed'
      else
        if representative_email.present? && representative_email == session_user&.email
          self.representative_user_status = 'ready_to_sign'
        else
          rep_user = SharedResources::RemoteUser.get_by_email(representative_email)
          if representative_email.present?
            if rep_user.nil?
              self.representative_user_status = 'not_invited'
            elsif rep_user['seller_id'] == session_user&.seller_id
              self.representative_user_status = 'invited'
            else
              self.representative_user_status = 'another_seller'
            end
          end
        end
      end
    end

    def started?
      agreed_by.present?
    end

    def before_save
      if agreed
        self.agree = true
        self.agreed_at = Time.now if agreed_at.blank?
        self.agreed_by_id = session_user.id if agreed_by.blank?
      end
    end
  end
end
