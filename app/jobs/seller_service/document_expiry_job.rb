module SellerService
  class DocumentExpiryJob < SharedModules::SlackReportingJob
    def mark_document_as_rejected seller, doc
      tag = SellerFieldStatus.find_or_create_by!(seller: seller, field: doc.to_s + '_ids')
      tag.update_attributes(status: 'rejected')
    end

    def perform
      stats = {
        expiring: 0,
        expired:  0,
      }

      Seller.live.each do |seller|

        next unless seller.status == :live

        d = (Date.today - seller.approved_version.updated_at.to_date).to_i

        expiry_service = DocumentExpiryService.new(seller_version: seller.approved_version)

        next if expiry_service.expiring_or_expired_documents.empty?

        expiry_service.expired_documents.keys.each do |doc|
          mark_document_as_rejected(seller, doc)
        end

        mailer = DocumentExpiryMailer.with(seller: seller, alerts: expiry_service.documents_serializable)

        if expiry_service.just_expired_documents.any? || (d > 0 && d == 28)
          mailer.document_expired_email.deliver_later
          stats[:expired] += 1
        elsif expiry_service.alerting_documents.any?
          mailer.document_expiring_soon_email.deliver_later
          stats[:expiring] += 1
        end
      end

      [
        {
          title: "Expiring soon",
          value: "#{stats[:expiring]} suppliers received warnings"
        },
        {
          title: "Now expired",
          value: "#{stats[:expired]} suppliers received warnings"
        },
      ]
    end
  end
end
