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
    has_one  :last_profile_version, -> { where(next_version_id: nil) }, class_name: 'SellerService::SellerProfileVersion', inverse_of: :seller

    has_one :last_version, -> { where(next_version_id: nil) }, class_name: 'SellerService::SellerVersion'
    has_one :last_version_with_schemes, -> {
      preload(panel_vendors: :scheme).where(next_version_id: nil)
    }, class_name: 'SellerService::SellerVersion'

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
      last_version&.created_at
    end

    def last_version
      versions.find{ |v| v.next_version_id == nil}
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
      if deactivated?
        :deactivated
      elsif last_version.nil?
        :archived
      elsif has_approved?
        if last_version.draft?
          :amendment_draft
        elsif last_version.pending?
          :amendment_pending
        elsif last_version.declined?
          :amendment_changes_requested
        else
          :live
        end
      else
        if last_version.declined?
          :changes_requested
        else
          last_version&.state&.to_sym
        end
      end
    end

    def valid_actions
      case status
      when :draft
        [:submit, :prefill_from_abr]
      when :pending
        [:withdraw, :assign, :approve, :decline]
      when :archived
        []
      when :changes_requested
        [:revise]
      when :live
        [:start_amendment, :make_inactive]
      when :amendment_draft
        [:submit, :cancel, :make_inactive]
      when :amendment_changes_requested
        [:revise, :make_inactive]
      when :amendment_pending
        [:withdraw, :make_inactive, :assign, :approve, :decline]
      when :deactivated
        [:make_active]
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
        form_object = form.new.load(last_version)
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

    def save_field_statuses(submitted_fields, version = nil)
      version ||= pending_version
      existing_field_statuses = field_statuses_hashed
      submitted_fields && submitted_fields.each do |field, decision|
        if existing_field_statuses[field.to_sym].present?
          existing_field_statuses[field.to_sym].update_attributes!(status: decision,
              value: version.send(field).inspect)
        else
          SellerService::SellerFieldStatus.create!(seller_id: id,
            field: field, status: decision,
            value: version.send(field).inspect)
        end
      end
      # seller_field_statuses.where.not(field: submitted_fields.keys).delete_all
      reload
    end

    def update_field_statuses(step, version = nil)
      version ||= draft_version
      raise SharedModules::AlertError.new("Invalid status: #{status}.") unless has_draft?
      existing_field_statuses = field_statuses_hashed
      forms[step].fields.each do |field|
        next unless version.respond_to? field
        if existing_field_statuses[field].nil?
         sfs =  SellerService::SellerFieldStatus.create!(seller_id: id,
            field: field, status: 'reviewed',
            value: version.send(field).inspect)
         existing_field_statuses[sfs.field.to_sym] = sfs
        end
        if existing_field_statuses[field] && version.send(field).inspect != existing_field_statuses[field].value
          existing_field_statuses[field].update_attributes!(status: 'reviewed')
        end
      end
      reload
    end

    def update_pending_version(version = nil)
      av = approved_version
      pv = version || pending_version
      rejected_fields = seller_field_statuses.select do |tag|
        tag.status != 'accepted' && av.send(tag.field) != pv.send(tag.field)
      end.map { |tag|
        [tag.field.to_sym, av.send(tag.field)]
      }.to_h.select{|k,v|pv.respond_to?(k.to_s + '=')}
      pv.update_attributes!(rejected_fields) if rejected_fields.any?
    end

    def decide(user, props)
      pending_version.update_attributes!(decided_by_id: user.id, decided_at: Time.now, response: props[:response])
      save_field_statuses(props[:field_statuses])
    end

    def create_profile(version, user)
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
      profile.edited_by_id = user.id
      profile.save!
    end

    def approve(user, props)
      decide(user, props)
      create_profile(pending_version, user) unless approved_version
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

    def make_inactive(user, props)
      approved_version.deactivate!
      self.deactivate!
      "Seller deactivated by #{user.email}. Response was: #{props[:response]}."
    end

    def make_active(user, props)
      self.activate!
      deactivated_version.activate!
      "Seller activated by #{user.email}. Response was: #{props[:response]}."
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
        # :corporate_structure,
        :business_structure,
        :services,
        :financial_statement_expiry,
      ]
    end

    # FIXME: should financial expiry move here?
    def auditable_fields
      [
        :receivership,
        :receivership_details,
        :bankruptcy,
        :bankruptcy_details,
        :investigations,
        :investigations_details,
        :legal_proceedings,
        :legal_proceedings_details,

        :financial_statement_ids,
        :professional_indemnity_certificate_ids,
        :professional_indemnity_certificate_expiry,
        :workers_compensation_certificate_ids,
        :workers_compensation_certificate_expiry,
        :product_liability_certificate_ids,
        :product_liability_certificate_expiry,
      ]
    end

    def base_fields_edited?
      seller_field_statuses.any? do |tag|
        base_fields.include?(tag.field.to_sym) && tag.status != 'accepted'
      end
    end

    def auditable_fields_edited?
      seller_field_statuses.any? do |tag|
        auditable_fields.include?(tag.field.to_sym) && tag.status != 'accepted'
      end
    end

    def auto_partial_approve!(user)
      version = pending_version || draft_version

      if auditable_fields_edited?
        create_version(version, new_version_state: 'pending')
        save_field_statuses(base_fields.map{|f| [f, 'accepted'] }.to_h, version)
        update_pending_version(version)
      else
        save_field_statuses(base_fields.map{|f| [f, 'accepted'] }.to_h, version)
      end

      approved_version.archive!
      version.submit! if version.draft?
      version.update_attributes!(submitted_by_id: user.id)
      version.approve!
      reload
    end

    def auto_submit!
      draft_version.submit! if draft_version
    end

    def auto_partial_approve_or_submit! version, user
      SellerService::Seller.transaction do
        if base_fields_edited?
          auto_partial_approve!(user)
        end

        if auditable_fields_edited?
          auto_submit!
        end
      end
      create_event(user, "Seller self approved by #{user.email}")
    end

    def auto_approve!(user)
      create_profile(pending_version, user)
      save_field_statuses((base_fields+auditable_fields).map{|f| [f, 'accepted'] }.to_h)
      pending_version.approve!
      make_live!
    end

    def no_legal_issue
      [
        :receivership,
        :bankruptcy,
        :investigations,
        :legal_proceedings,
      ].none? do |field|
        pending_version.send(field)
      end
    end

    def auto_review!(user)
      if !approved_version && no_legal_issue
        auto_approve!(user)
        create_event(user, "Seller auto approved by #{user.email}")
      end
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

      auto_review!(user)

      "Seller submitted by #{user.email}."
    end

    def update_search_columns profile_version
      versions.where.not(state: :archived).each do |version|
          version.update_attributes!(
            flagship_product: profile_version.flagship_product,
            summary: profile_version.summary
          )
      end
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

    def create_profile_version(user)
      copy = nil
      SellerService::SellerProfileVersion.transaction do
        v = last_profile_version
        copy = SellerService::SellerProfileVersion.new(v.attributes.except(
          "id",
          "next_version_id",
          "created_at",
          "updated_at",
        ))
        copy.edited_by_id = user.id
        copy.save!

        v.update_attributes(next_version: copy)
      end
      reload
      copy
    end

    def self.profile_forms
      {
        search_description: SellerService::Profile::SearchDescriptionForm,
        company_description: SellerService::Profile::CompanyDescriptionForm,
        contact_detail: SellerService::Profile::ContactDetailForm,
        accreditation_and_license: SellerService::Profile::AccreditationAndLicenseForm,
        membership_and_award: SellerService::Profile::MembershipAndAwardForm,
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
        business_identifier: SellerService::Account::BusinessIdentifierForm,
        product_category: SellerService::Account::ProductCategoryForm,
        legal_disclosure: SellerService::Account::LegalDisclosureForm,
        insurance_document: SellerService::Account::InsuranceDocumentForm,
        financial_document: SellerService::Account::FinancialDocumentForm,
        scheme_and_panel: SellerService::Account::SchemeAndPanelForm,
      }
    end

    def get_public_abr abn
      r = SharedModules::Abr.lookup(abn)
      {
        address: r && {
          postcode: r[:address_post_code],
          state: r[:address_state_code],
        }
      }
    rescue => e
      Airbrake.notify_sync(e.message, {
        abn: abn,
        trace: e.backtrace.select{|l|l.match?(/buy-nsw/)},
      })
      return {}
    end

    def get_private_abr abn
      r = SharedModules::Abr.search(abn)[:data][:response][:current_abn_record]
      a = r[:main_business_physical_address]
      c = r[:contact]&.first
      {
        address: a && {
          address_1: a[:address_line1],
          address_2: a[:address_line2],
          address_3: '',
          suburb: a[:suburb],
          state: a[:state_code],
          postcode: a[:postcode],
          country: a[:country_code] || 'AUS',
        },
        contact: c && {
          contact_first_name: c.fetch(:preferred_name,   {})[:given_name],
          contact_last_name:  c.fetch(:preferred_name,   {})[:family_name],
          contact_email: c.fetch(:email_address,         {})[:email_address]&.downcase,
          contact_phone: c.fetch(:business_phone_number, {})[:telephone_number_prefix].to_s +
                         c.fetch(:business_phone_number, {})[:telephone_number].to_s
        },
      }
    rescue => e
      Airbrake.notify_sync(e.message, {
        abn: abn,
        trace: e.backtrace.select{|l|l.match?(/buy-nsw/)},
      })
      return {}
    end

    def prefill_from_abr(user, props = nil)
      v = draft_version
      abn = (props && props[:abn]) || v.abn
      h = get_public_abr abn
      v.addresses.push({}) if v.addresses.blank?

      # v.addresses.last[:address] = h[:address][:address_1] if v.addresses.last[:address].blank?
      v.addresses.last[:address] = '' if v.addresses.last[:address].nil?

      # v.addresses.last[:address_2] = h[:address][:address_2] if v.addresses.last[:address_2].blank?
      v.addresses.last[:address_2] = '' if v.addresses.last[:address_2].nil?

      # v.addresses.last[:address_3] = h[:address][:address_3] if v.addresses.last[:address_3].blank?
      v.addresses.last[:address_3] = '' if v.addresses.last[:address_3].nil?

      # v.addresses.last[:suburb] = h[:address][:suburb] if v.addresses.last[:suburb].blank?
      v.addresses.last[:suburb] = '' if v.addresses.last[:suburb].nil?

      v.addresses.last[:postcode] = h[:address][:postcode] if v.addresses.last[:postcode].blank?
      v.addresses.last[:state] = h[:address][:state]&.downcase if v.addresses.last[:state].blank?

      # if v.addresses.last[:country].blank?
      #   v.addresses.last[:country] = ISO3166::Country.find_country_by_alpha3(
      #   h[:address][:country])&.un_locode.to_s
      # end
      v.addresses.last[:country] = '' if v.addresses.last[:country].nil?

      v.save!

      "Draft initiated from ABR search API using ABN: " + abn.to_s
    end
  end
end
