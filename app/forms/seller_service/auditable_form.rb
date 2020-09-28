module SellerService
  class AuditableForm < SellerService::BaseForm

    def update_field_statuses(seller)
      existing_field_statuses = seller.field_statuses_hashed
      (two_way_fields+back_end_fields).each do |field|
        if existing_field_statuses[field].nil?
          sfs = SellerService::SellerFieldStatus.create!(seller_id: seller.id,
            field: field, status: 'reviewed',
            value: send(field).inspect)
          existing_field_statuses[field] = sfs
        end

        if feedback_fields.include?(field) &&
            send(field).inspect != existing_field_statuses[field].value
          seller.field_statuses_hashed[field].update_attributes!(status: 'reviewed')
        end
      end
    end

    def optional?
      false
    end

    def started?
      before_validate if defined? before_validate
      feedback_fields.any? do |field|
        send(field).present? || send(field) == false
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
      if seller.draft_version.present?
        if started? && valid? && !declined?(seller)
          :done
        elsif declined?(seller)
          :declined
        elsif started?
          :doing
        else
          :todo
        end
      else
        if accepted?(seller)
          :accepted
        elsif declined?(seller)
          :declined
        else
          :under_review
        end
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
