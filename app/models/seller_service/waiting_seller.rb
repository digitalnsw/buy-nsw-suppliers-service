module SellerService
  class WaitingSeller < SellerService::ApplicationRecord
    self.table_name = 'waiting_sellers'
    include AASM

    before_save :normalise_abn
    belongs_to :seller, optional: true

    default_scope -> { order('name ASC') }

    aasm column: :invitation_state do
      state :created, initial: true
      state :invited
      state :joined
      state :submitted
      state :deactivated

      event :mark_as_invited do
        transitions from: :created, to: :invited
      end

      event :mark_as_joined do
        transitions from: :invited, to: :joined
      end

      event :mark_as_submitted do
        transitions from: :joined, to: :submitted
      end

      event :deactivate do
        transitions from: [:invited, :created], to: :deactivated
      end
    end

    def editable?
      invitation_state == 'created'
    end

    def deactivatable?
      invitation_state.in? ['created', 'invited']
    end

    def invitable?
      may_mark_as_invited?
    end

    def complete?
      name.present? &&
      abn.present? && ABN.valid?(abn)
      state.in?(["nsw", "act", "nt", "qld", "sa", "tas", "vic", "wa", "outside_au"]) &&
      country.in?(ISO3166::Country.translations.keys) &&
      contact_email.present? &&
      contact_name.present?
    end

    def prepare_invitation!
      WaitingSeller.transaction do
        self.invitation_token = SecureRandom.hex(24)
        self.invited_at = Time.now
        mark_as_invited
        save!
      end
    end

    scope :in_invitation_state, ->(state) { where(invitation_state: state) }

    def create_seller!
      SellerService::Seller.transaction do
        seller = SellerService::Seller.create!
        num_emp_h = {
          "0-19" => '5to19',
          "20-100" => '50to99',
          "101-200" => '100to199',
          "200+" => '200plus',
        }
        version = SellerService::SellerVersion.new(
          seller: seller,
          offers_ict: true,
          offers_cloud: false,
          govdc: false,
          started_at: Time.now,
          name: name,
          establishment_date: establishment_date,
          number_of_employees: num_emp_h[number_of_employees],
          australia_employees: num_emp_h[number_of_employees],
          nsw_employees: num_emp_h[number_of_employees],
          abn: abn,
          contact_first_name: contact_name.partition(' ').first,
          contact_last_name: contact_name.partition(' ').last,
          contact_phone: contact_phone,
          contact_email: contact_email,
          contact_position: contact_position,
          representative_first_name: contact_name.partition(' ').first,
          representative_last_name: contact_name.partition(' ').last,
          representative_phone: contact_phone,
          representative_email: contact_email,
          representative_position: contact_position,
          website_url: website_url,
          addresses: [
            {
              address: address_1,
              address_2: address_2,
              address_3: address_3,
              suburb: suburb,
              state: attributes['state'], # state is conflicting with aasm
              postcode: postcode,
              country: country,
            }
          ]
        )
        case corporate_structure
        when "Australian / NZ Company"
          version.corporate_structure = 'standalone'
          version.business_structure = 'company'
        when "Multi-national company"
          version.corporate_structure = 'overseas'
          version.business_structure = 'company'
        when "Partnership"
          version.corporate_structure = 'subsidiary'
          version.business_structure = 'partnership'
        when "Sole Trader"
          version.corporate_structure = 'standalone'
          version.business_structure = 'sole-trader'
        when "Other Type"
          version.corporate_structure = 'standalone'
          version.business_structure = 'company'
        else
          version.corporate_structure = 'standalone'
          version.business_structure = 'company'
        end
        version.save!
        update_invitation_state!(seller)
      end
    end

    def update_invitation_state!(seller)
      self.seller = seller
      self.invitation_token = nil
      self.joined_at = Time.now
      self.mark_as_joined

      self.save!
    end

    private

    def normalise_abn
      self.abn = ABN.new(abn).to_s if ABN.valid?(abn)
    end

    def self.convert_state fields
      if fields['Country'].present? && fields['Country'].upcase != 'AUSTRALIA'
        'outside_au'
      elsif fields['State']&.downcase&.in? ["nsw", "act", "nt", "qld", "sa", "tas", "vic", "wa"]
        fields['State'].downcase
      else
        ''
      end
    end

    def self.import xml_doc
      list = xml_doc.css("row").map do |row|
        fields = row.css("field").map do |field|
          [field['name'], field.inner_text]
        end.compact.to_h

        SellerService::WaitingSeller.new({
          name: fields['CompanyName'] || '',
          abn: fields['ABN'] || '',
          address_1: fields["Address1"] || '',
          address_2: fields["Address2"] || '',
          address_3: '',
          suburb: fields["City"] || '',
          postcode: fields["Postcode"] || '',
          state: convert_state(fields),
          country: ISO3166::Country.find_country_by_name(fields["Country"])&.un_locode || '',
          contact_name: fields["ContactName"] || '',
          contact_phone: fields["CompanyPhone"] || '',
          contact_email: fields["Email"] || '',
          contact_position: fields["ContactPosition"] || '',
          number_of_employees: fields["SMEStatus"] || '',
          website_url: fields["WebAddress"] || '',
          corporate_structure: fields["Type_of_org"].to_s.gsub(/&lt;[^&]*&gt;/, '') || '',
          establishment_date: (Date.parse(fields["Date_Established"]).to_s.gsub(/&lt;[^&]*&gt;/, '') rescue ''),
        })
      end

      # FIXME move this to service
      taken_emails = User.all.map(&:email).to_set
      taken_abns = SellerVersion.where(state: [:pending, :approved]).map{|v|v.abn.to_s.gsub(' ','')}.uniq.compact.select(&:present?).to_set
      invited_emails = WaitingSeller.all.map(&:contact_email).to_set
      invited_abns = WaitingSeller.all.map{|ws|ws.abn.gsub(' ','')}.to_set

      new_emails = Set.new
      new_abns = Set.new

      cleansed_data = []
      list.select do |ws|
        cleansed_data.push(ws) unless
          taken_emails.include?(ws.contact_email) ||
          taken_abns.include?(ws.abn) ||
          invited_emails.include?(ws.contact_email) ||
          invited_abns.include?(ws.abn) ||
          new_emails.include?(ws.contact_email) ||
          new_abns.include?(ws.abn)

        new_abns.add(ws.abn.gsub(' ',''))
        new_emails.add(ws.contact_email)
      end; nil

      cleansed_data.each do |ws|
        ws.save!
      end
      cleansed_data.size
    end
  end
end
