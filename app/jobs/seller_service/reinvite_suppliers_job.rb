module SellerService
  class ReinviteSuppliersJob < SharedModules::SlackReportingJob
    def perform
      reinvited_to_join = 0

      # FIXME: User is used cross service
      taken_emails = User.all.map(&:email).to_set
      taken_abns = SellerVersion.where(state: [:approved, :pending]).map(&:abn).to_set

      WaitingSeller.invited.each do |seller|

        next if taken_emails.include?(seller.contact_email) || taken_abns.include?(seller.abn)

        d = (Date.today - seller.invited_at.to_date).to_i
        next if d <= 0 || d % 28 != 0

        mailer = WaitingSellerMailer.with(waiting_seller: seller)

        mailer.reinvite_to_join_email.deliver_later

        reinvited_to_join += 1
      end

      # return the fields back to the slack message hook
      [
        {
          title: "Reinvited to join",
          value: "#{reinvited_to_join} invitations sent",
        },
      ]
    end
  end
end
