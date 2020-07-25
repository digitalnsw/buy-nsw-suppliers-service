module SellerService
  class DocumentExpiryService
    attr_accessor :document_names, :warning_times, :seller_version

    def initialize(opts = {})
      @document_names = opts[:document_names] || [
        :financial_statement,
        :professional_indemnity_certificate,
        :workers_compensation_certificate,
        :product_liability_certificate,
      ]

      @warning_times = opts[:warning_times] || [
        8.weeks,
        4.weeks,
        2.weeks,
        1.weeks,
        2.days,
        1.days,
      ]

      @seller_version = opts[:seller_version]
    end

    def expiring_or_expired_documents
      @expiring_or_expired_documents ||= document_names.collect do |doc|
        expiry_date = seller_version.send("#{doc}_expiry")
        if expiry_date.present?
          dur = (expiry_date - Date.today).to_i.days
          if dur <= @warning_times.max
            [doc, dur]
          end
        end
      end.compact.to_h
    end

    def documents_serializable
      expiring_or_expired_documents.map do |k, dur|
        {
          name: k.to_s,
          expiry: dur.positive? ? dur.inspect : 'Now expired'
        }
      end
    end

    def about_to_expire_documents
      expiring_or_expired_documents.select do |doc, dur|
        dur > 0.days
      end
    end

    def alerting_documents
      about_to_expire_documents.select do |doc, dur|
        dur.in? @warning_times
      end
    end

    def just_expired_documents
      expiring_or_expired_documents.select do |doc, dur|
        dur == 0.days
      end
    end

    def expired_documents
      expiring_or_expired_documents.select do |doc, dur|
        dur <= 0.days
      end
    end
  end
end
