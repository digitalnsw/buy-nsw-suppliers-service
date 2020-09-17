module SellerService
  class Seller < SellerService::ApplicationRecord
    self.table_name = 'sellers'
    include AASM
    extend Enumerize

    include SellerService::Concerns::Documentable
    include SellerService::Concerns::StateScopes

    acts_as_paranoid column: :discarded_at

    has_one :waiting_seller
    has_many :versions, class_name: 'SellerService::SellerVersion', dependent: :destroy, inverse_of: :seller
    has_many :profile_versions, class_name: 'SellerService::SellerProfileVersion', dependent: :destroy, inverse_of: :seller
    has_one  :last_profile_version, -> { where(next_version: nil) }, class_name: 'SellerService::SellerProfileVersion', inverse_of: :seller

    has_one :last_edited_by, through: :last_version, source: :edited_by, inverse_of: :seller
    has_many :seller_field_statuses, class_name: "SellerService::SellerFieldStatus", dependent: :destroy, inverse_of: :seller

    aasm column: :state do
      state :draft, initial: true
      state :live
      state :deactivated

      event :make_live do
        transitions from: :draft, to: :live
      end

      event :deactivate do
        transitions from: :live, to: :deactivated
      end

      event :activate do
        transitions from: :deactivated, to: :live
      end
    end

    def team
      SharedResources::RemoteUser.get_team(id)
    end

    def events
      required_forms.reject!{|k|k.in? []} if live?
      SharedResources::RemoteEvent.get_events(id, 'Seller')
    end

    def last_edited_at
      latest_version&.created_at
    end

    def last_version
      versions.find{ |v| v.next_version_id == nil}
    end

    def latest_version
      versions.where.not(state: 'archived').order(:id).last
    end

    def draft_version
      versions.find{ |v| v.draft? }
    end

    def pending_version
      versions.find{ |v| v.pending? }
    end

    def approved_version
      versions.find { |v| v.approved? }
    end

    def declined_version
      versions.find { |v| v.declined? }
    end

    def deactivated_version
      versions.find { |v| v.deactivated? }
    end

    def no_reject?
      seller_field_statuses.none?{ |f| f.status == 'rejected' }
    end

    def field_statuses_hashed
      seller_field_statuses.map { |fs| [fs.field.to_sym, fs] }.to_h
    end

    def has_draft?
      draft_version.present?
    end

    def has_pending?
      pending_version.present?
    end

    def has_approved?
      approved_version.present?
    end

    def has_declined?
      declined_version.present?
    end

    def has_deactivated?
      deactivated_version.present?
    end

    def previous_decision(field)
      seller_field_statuses.select{|tag|tag.field == field.to_s}.try(:first).try(:status)
    end

    def status
      if latest_version.nil?
        :archived
      elsif has_approved?
        if latest_version.draft?
          :amendment_draft
        elsif latest_version.pending?
          :amendment_pending
        elsif latest_version.declined?
          :amendment_changes_requested
        else
          :live
        end
      else
        if latest_version.declined?
          :changes_requested
        else
          latest_version&.state&.to_sym
        end
      end
    end

    def valid_actions
      case status
      when :draft
        [:submit]
      when :pending
        [:withdraw, :assign, :approve, :decline]
      when :archived
        []
      when :changes_requested
        [:revise]
      when :deactivated
        [:activate]
      when :live
        [:start_amendment, :deactivate]
      when :amendment_draft
        [:submit, :cancel, :deactivate]
      when :amendment_changes_requested
        [:revise, :deactivate]
      when :amendment_pending
        [:withdraw, :deactivate, :assign, :approve, :decline]
      end
    end

    def create_event(user, note)
      SharedResources::RemoteEvent.generate_token(user)
      SharedResources::RemoteEvent.create_event(id, 'Seller', user.id, 'Event::Seller', note)
    end

    def run_action(action, user: nil, props: {}) # assignee: nil, statuses: nil, response: nil
      raise SharedModules::AlertError.new("Invalid action #{action} in status #{status}, please refresh the page.") unless action.in? valid_actions
      raise SharedModules::AlertError.new("Unauthorized access #{action} with user #{user.email}.") unless user.is_admin? ||
        (user.roles.include?('seller') && self.id == user.seller_id) 
      SellerService::Seller.transaction do
        note = send(action, user, props)
        create_event(user, note)
      end
    end

    def create_version(seller_version, new_version_state:)
      copy = SellerService::SellerVersion.create!(seller_version.attributes.except(
        "id",
        "next_version_id",
        "assigned_to_id",
        "assigned_by_id",
        "assigned_at",
        "submitted_by_id",
        "submitted_at",
        "decided_by_id",
        "decided_at",
        "created_at",
        "updated_at",
      ).merge(
        "state" => new_version_state,
      ))

      last_version.update_attributes(next_version: copy)
      reload
      copy
    end

    def can_be_withdrawn?
      has_pending? && pending_version.assigned_to_id.nil?
    end

    def can_be_submitted?
      required_forms = live? ? self.class.account_forms : forms
      required_forms.all? do |key, form|
        form_object = form.new.load(latest_version)
        result = !form_object.declined?(self) &&
                 ( form_object.valid? ||
                   ( form_object.optional? && !form_object.started? )
                 )
        result
      end
    end

    def withdraw(user, props)
      raise SharedModules::AlertError.new("Profile can't be withdrawn after assignement.") unless can_be_withdrawn?
      pending_version.withdraw!
      "Seller submission withdrawn by #{user.email}."
    end

    def assign(user, props)
      pending_version.update_attributes!(assigned_by_id: user.id,
                                         assigned_at: Time.now, assigned_to_id: props[:assignee][:id])
      "Seller submission assigned by #{user.email} to #{props[:assignee][:email]}."
    end

    def save_field_statuses(submitted_fields)
      existing_field_statuses = field_statuses_hashed
      submitted_fields && submitted_fields.each do |field, decision|
        if existing_field_statuses[field.to_sym].present?
          existing_field_statuses[field.to_sym].update_attributes!(status: decision,
              value: pending_version.send(field).inspect)
        else
          SellerService::SellerFieldStatus.create!(seller_id: id,
            field: field, status: decision,
            value: pending_version.send(field).inspect)
        end
      end
      seller_field_statuses.where.not(field: submitted_fields.keys).delete_all
      reload
    end

    def update_field_statuses(step)
      raise SharedModules::AlertError.new("Invalid status: #{status}.") unless has_draft?
      existing_field_statuses = field_statuses_hashed
      forms[step].fields.each do |field|
        if existing_field_statuses[field] && draft_version.send(field).inspect != existing_field_statuses[field].value
          existing_field_statuses[field].update_attributes!(status: 'reviewed')
        end
      end
      reload
    end

    def update_pending_version
      av = approved_version
      pv = pending_version
      rejected_fields = seller_field_statuses.select do |tag|
        tag.status != 'accepted' && av.send(tag.field) != pv.send(tag.field)
      end.map { |tag| [tag.field.to_sym, av.send(tag.field)] }.to_h
      pv.update_attributes!(rejected_fields) if rejected_fields.any?
    end

    def decide(user, props)
      pending_version.update_attributes!(decided_by_id: user.id, decided_at: Time.now, response: props[:response])
      save_field_statuses(props[:field_statuses])
    end

    def create_profile(version)
      profile = SellerService::SellerProfileVersion.new(version.attributes.slice(
        "flagship_product",
        "summary",
        "website_url",
        "linkedin_url",
        "facebook_url",
        "twitter_url",
        "youtube_url",
        "instagram_url",
        "accreditations",
        "accreditation_document_ids",
        "licenses",
        "license_document_ids",
        "engagements",
        "awards",
      ))
      profile.seller = version.seller
      profile.save!
    end

    def approve(user, props)
      decide(user, props)
      create_profile(pending_version) unless approved_version
      approved_version.archive! if approved_version
      pending_version.approve!
      self.make_live! if self.draft?
      "Seller approved by #{user.email}. Response was: #{props[:response]}."
    end

    def decline(user, props)
      decide(user, props)
      if has_approved?
        create_version(pending_version, new_version_state: 'declined')
        update_pending_version
        approved_version.archive!
        pending_version.approve!
      else
        create_version(pending_version, new_version_state: 'declined')
        pending_version.archive!
      end
      "Seller declined by #{user.email}. Response was: #{props[:response]}."
    end

    def cancel(user, props)
      #The value field on the field status is not correct any more and should be updated to the value of the live version
      seller_field_statuses.where(status: 'reviewed').update_all(status: 'accepted')
      draft_version.cancel!
      reload
      "Edits canceled by #{user.email}."
    end

    def deactivate(user, props)
      approved_version.deactivate!
      self.deactivate!
      "Seller deactivated by #{user.email}."
    end

    def activate(user, props)
      self.activate!
      deactivated_version.activate!
      "Seller activated by #{user.email}."
    end

    def revise(user, props)
      declined_version.revise!
      "User revised seller #{user.email}."
    end

    def start_amendment(user, props)
      create_version(approved_version, new_version_state: 'draft')
      "User started amending seller #{user.email}."
    end

    def update_waiting_seller
      ws = SellerService::WaitingSeller.where(seller_id: self.id).first
      ws.mark_as_submitted! if ws && ws.joined?
    end


    def base_fields
      [
        :name,
        :abn,
        :establishment_date,
        :contact_first_name,
        :contact_last_name,
        :contact_email,
        :contact_phone,
        :contact_position,
        :representative_first_name,
        :representative_last_name,
        :representative_email,
        :representative_phone,
        :representative_position,
        :addresses,
        :number_of_employees,
        :australia_employees,
        :nsw_employees,
        :annual_turnover,
        :start_up,
        :sme,
        :not_for_profit,
        :australian_owned,
        :regional,
        :indigenous,
        :disability,
        :corporate_structure,
        :business_structure,
        :services,
        :receivership,
        :receivership_details,
        :bankruptcy,
        :bankruptcy_details,
        :investigations,
        :investigations_details,
        :legal_proceedings,
        :legal_proceedings_details,

        :financial_statement_ids,
        :financial_statement_expiry,
        :professional_indemnity_certificate_ids,
        :professional_indemnity_certificate_expiry,
        :workers_compensation_certificate_ids,
        :workers_compensation_certificate_expiry,
        :product_liability_certificate_ids,
        :product_liability_certificate_expiry,
        :schemes_and_panels,
      ]
    end

    def auto_approve!
      create_profile(pending_version)
      save_field_statuses(base_fields.map{|f| [f, 'accepted'] }.to_h)
      pending_version.approve!
      make_live!
    end

    def submit(user, props)
      raise SharedModules::AlertError.new("Supplier application can't be submitted unless all forms are completed.") unless can_be_submitted?
      update_waiting_seller
      draft_version.update_attributes!(submitted_by_id: user.id, submitted_at: Time.now)
      draft_version.submit!
      ::SharedModules::SlackPostJob.perform_later(
        pending_version.id,
        :seller_version_submitted.to_s
      )

      unless approved_version
        auto_approve!
        create_event(user, "Seller self approved by #{user.email}")
      end

      "Seller submitted by #{user.email}."
    end

    def self.forms
      {
#        eligibility: SellerService::EligibilityForm,
        business_name: SellerService::BusinessNameForm,
        contact_detail: SellerService::ContactDetailForm,
        company_type: SellerService::CompanyTypeForm,
        product_category: SellerService::ProductCategoryForm,
        legal_disclosure: SellerService::LegalDisclosureForm,
#        insurance_and_financial_document: SellerService::InsuranceAndFinancialDocumentForm,
#        company_profile: SellerService::CompanyProfileForm,
#        membership_and_award: SellerService::MembershipAndAwardForm,
#        accreditation_and_license: SellerService::AccreditationAndLicenseForm,
#        complete_application: SellerService::CompleteApplicationForm,
      }
    end

    def forms
      self.class.forms
    end

    def create_profile_version
      v = last_profile_version
      copy = SellerService::SellerProfileVersion.create!(v.attributes.except(
        "id",
        "next_version_id",
        "created_at",
        "updated_at",
      ))

      v.update_attributes(next_version: copy)
      reload
      copy
    end

    def self.profile_forms
      {
        essential_information: SellerService::Profile::EssentialInformationForm,
        contact_detail: SellerService::Profile::ContactDetailForm,
        reputation_and_distinction: SellerService::Profile::ReputationAndDistinctionForm,
        capability_and_experty: SellerService::Profile::CapabilityAndExpertyForm,
        reference_and_case_study: SellerService::Profile::ReferenceAndCaseStudyForm,
        government_credential: SellerService::Profile::GovernmentCredentialForm,
        team_member: SellerService::Profile::TeamMemberForm,
        promotional_video: SellerService::Profile::PromotionalVideoForm,
      }
    end

    def self.account_forms
      {
        business_name_and_abn: SellerService::Account::BusinessNameAndAbnForm,
        contact_detail: SellerService::Account::ContactDetailForm,
        business_address: SellerService::Account::BusinessAddressForm,
        company_type_and_size: SellerService::Account::CompanyTypeAndSizeForm,
        business_category: SellerService::Account::BusinessCategoryForm,
        legal_disclosure: SellerService::Account::LegalDisclosureForm,
        insurance_document: SellerService::Account::InsuranceDocumentForm,
        financial_document: SellerService::Account::FinancialDocumentForm,
        scheme_and_panel: SellerService::Account::SchemeAndPanelForm,
      }
    end

#    def seller_decisions
#      @seller_decisions ||= latest_version.tags.map do |sfs|
#        [sfs.field.to_sym, sfs]
#      end.to_h
#    end
  end
end
