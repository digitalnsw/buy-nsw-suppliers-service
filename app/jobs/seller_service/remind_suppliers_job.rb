module SellerService
  class RemindSuppliersJob < SharedModules::SlackReportingJob
    def perform
      reminded_to_register = 0
      reminded_to_complete = 0
      reminded_to_review = 0
      reminded_to_update_profile = 0

      SellerService::Seller.all.eager_load(:last_profile_version, :last_version).each do |seller|

        if seller.status == :live
          profile = seller.last_profile_version
          next if profile.nil?
          d = (Date.today - profile.updated_at.to_date).to_i
        else
          version = seller.last_version
          next if version.nil?
          d = (Date.today - version.updated_at.to_date).to_i
        end

        next if d <= 0 || d % 28 != 0

        if seller.status == :started
          RemindSupplierMailer.deliver_many(:reminder_to_register_email, {
            seller: seller
          })
          reminded_to_register += 1
        elsif seller.status == :draft
          RemindSupplierMailer.deliver_many(:reminder_to_complete_email, {
            seller: seller
          })
          reminded_to_complete += 1
        elsif seller.status == :changes_requested
          RemindSupplierMailer.deliver_many(:reminder_to_review_email, {
            seller: seller
          })
          reminded_to_review += 1
        elsif seller.status == :live && d == 28
          RemindSupplierMailer.deliver_many(:reminder_to_update_profile_email, {
            seller: seller
          })
          reminded_to_update_profile += 1
        elsif seller.status == :amendment_draft && d == 28
          RemindSupplierMailer.deliver_many(:reminder_to_complete_email, {
            seller: seller
          })
          reminded_to_complete += 1
        elsif seller.status == :amendment_changes_requested && d == 28
          RemindSupplierMailer.deliver_many(:reminder_to_review_email, {
            seller: seller
          })
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
