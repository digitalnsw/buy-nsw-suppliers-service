module SellerService::Account
  class AuditableForm < SellerService::BaseForm
    def update_field_statuses(seller)
      (two_way_fields+back_end_fields).each do |field|
        if feedback_fields.include?(field) &&
            seller.field_statuses_hashed[field] &&
            send(field).to_s != seller.field_statuses_hashed[field].value
          seller.field_statuses_hashed[field].update_attributes!(status: 'reviewed')
        end
      end
    end

    def feedbacks(seller)
      feedback_fields.map do |field|
        if seller.field_statuses_hashed[field]
          [
            field,
            seller.field_statuses_hashed[field].status,
          ]
        end
      end.compact.to_h
    end

    def rejections(seller)
      feedback_fields.map do |field|
        if seller.field_statuses_hashed[field] && seller.field_statuses_hashed[field].status == 'rejected'
          [
            field,
            'Changes requested upon your previous submission'
          ]
        end
      end.compact.to_h
    end

    def optional?
      false
    end

    def accepted?(seller)
      feedback_fields.all? do |field|
        seller.field_statuses_hashed[field]&.status == 'accepted'
      end
    end

    def declined?(seller)
      feedback_fields.any? do |field|
        seller.field_statuses_hashed[field]&.status == 'rejected'
      end
    end

    def status(seller)
      if declined?(seller)
        :declined
      elsif seller.pending_version.present? && seller.can_be_withdrawn?
        :pending
      elsif seller.pending_version.present? && !seller.can_be_withdrawn?
        :pending_locked
      elsif accepted?(seller) && valid?
        :accepted
      elsif seller.draft_version.present? && valid?
        :edited
      else
        :invalid
      end
    end

    def feedback_fields
      self.class.feedback_fields
    end

    def self.feedback_fields
      @feedback_fields || []
    end
  end
end
