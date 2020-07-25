module SellerService
  class RemindSuppliersJob < SharedModules::SlackReportingJob
    def perform
      reminded_to_register = 0
      reminded_to_complete = 0
      reminded_to_review = 0
      reminded_to_update_profile = 0

      Seller.all.each do |seller|

        if seller.status == :live
          profile = seller.profile_versions.order(id: :desc).first
          next if profile.nil?
          d = (Date.today - profile.updated_at.to_date).to_i
        else
          version = seller.latest_version
          next if version.nil?
          d = (Date.today - version.updated_at.to_date).to_i
        end

        next if d <= 0 || d % 28 != 0

        mailer = RemindSupplierMailer.with(seller: seller)

        if seller.status == :started
          mailer.reminder_to_register_email.deliver_later
          reminded_to_register += 1
        elsif seller.status == :draft
          mailer.reminder_to_complete_email.deliver_later
          reminded_to_complete += 1
        elsif seller.status == :changes_requested
          mailer.reminder_to_review_email.deliver_later
          reminded_to_review += 1
        elsif seller.status == :live && d == 28
          mailer.reminder_to_update_profile_email.deliver_later
          reminded_to_update_profile += 1
        elsif seller.status == :amendment_draft && d == 28
          mailer.reminder_to_complete_email.deliver_later
          reminded_to_complete += 1
        elsif seller.status == :amendment_changes_requested && d == 28
          mailer.reminder_to_review_email.deliver_later
          reminded_to_review += 1
        end

      end

      # return the fields back to the slack message hook
      [
        {
          title: "Reminded to register",
          value: "#{reminded_to_register} reminders sent",
        },
        {
          title: "Reminded to complete and submit",
          value: "#{reminded_to_complete} reminders sent",
        },
        {
          title: "Reminded to review",
          value: "#{reminded_to_review} reminders sent",
        },
        {
          title: "Reminded to update profile",
          value: "#{reminded_to_update_profile} reminders sent",
        },
      ]
    end
  end
end
