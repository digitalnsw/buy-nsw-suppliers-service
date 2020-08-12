module SellerService
  class InviteSuppliersJob < SharedModules::SlackReportingJob
    def perform
      invited_to_join = 0

      # FIXME: User is used cross service
      taken_emails = User.all.map(&:email).to_set
      taken_anbs = SellerVersion.where(state: [:approved, :pending]).map(&:abn).to_set

      SellerService::WaitingSeller.created.each do |seller|

        break if invited_to_join >= 300

        next if taken_emails.include?(seller.contact_email) || taken_anbs.include?(seller.abn)

        next unless ENV['DEPLOYMENT_ENVIRONMENT'] == 'production' || seller.contact_email.match?(/test/)

        next unless seller.invitable? && seller.complete?

        seller.prepare_invitation!

        mailer = WaitingSellerMailer.with(waiting_seller: seller)

        mailer.invitation_email.deliver_later

        invited_to_join += 1
      end

      # return the fields back to the slack message hook
      [
        {
          title: "Invited to join",
          value: "#{invited_to_join} invitations sent",
        },
      ]
    end
  end
end
