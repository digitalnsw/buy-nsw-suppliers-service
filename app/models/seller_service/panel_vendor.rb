module SellerService
  class PanelVendor < ApplicationRecord
    self.table_name = 'panel_vendors'

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
      abn_ex_h = {
        "NE" => "non-exempt",
        "EN" => "non-australian",
        "EI" => "insufficient-turnover",
        "EO" => "other",
      }
      num_emp_h = {
        "0-19" => '5to19',
        "20-100" => '50to99',
        "101-200" => '100to199',
        "200+" => '200plus',
      }
      corp_st_h = {
        "Australian / NZ Company" => 'standalone',
        "Multi-national company" => 'overseas',
        "Partnership" => 'subsidiary',
        "Sole Trader" => 'standalone',
        "Other Type" => 'standalone',
      }
      biz_st_h = {
        "Australian / NZ Company" => 'company',
        "Multi-national company" => 'company',
        "Partnership" => 'partnership',
        "Sole Trader" => 'sole-trader',
        "Other Type" => 'company',
      }

      rows = xml_doc.css('row').to_a.map do |row|
        fields = row.css("field").map do |field|
          [field['name'], field.inner_text]
        end.compact.to_h
      end

      rows.each do |row|
        begin
          next if row['PanelVendorUUID'].blank? || row['ABN'].blank? || row['Email'].blank?
          pv = PanelVendor.find_or_initialize_by(uuid: row['PanelVendorUUID'])
          pv.abn = ABN.new(row['ABN'].gsub('-', '')).to_s
          pv.email = row['Email'].downcase
          pv.fields = row
          pv.save!

          abn = row['ABN'].gsub('-', '')

          next unless abn.present? && ABN.valid?(abn)
          abn = ABN.new(abn).to_s

          scheme = SellerService::SupplierScheme.find_or_initialize_by(
            scheme_id: pv.fields['SchemeID']
          )
          scheme.category = pv.fields['SchemeCategory']
          scheme.title = pv.fields['SchemeTitle']
          scheme.save if scheme.has_changes_to_save?

          SellerService::Seller.transaction do
            sv = SellerVersion.where(state: [:pending, :approved], abn: abn).order(id: :desc).first
            sv ||= SellerVersion.where(abn: abn).where.not(state: :archived).order(id: :desc).first

            if sv
              # FIXME: here scheme is being added only to one version.
              # If version is in draft or pending, it should be added to two versions
              sv.schemes_and_panels |= [ scheme.id ] if scheme.id
              sv.save! if sv.has_changes_to_save?
              seller = sv.seller
              seller.update_attributes!(uuid: pv.uuid) if seller.uuid.nil?
            else
              seller = SellerService::Seller.create!(state: :draft, uuid: pv.uuid)
              sv = SellerService::SellerVersion.create!({
                seller_id: seller.id,
                state: :draft,
                started_at: Time.now,
                schemes_and_panels: [ scheme.id ].compact,

                name: row['CompanyName'] || '',
                abn: abn,
                abn_exempt: abn_ex_h[row['ABNExempt']],
                abn_exempt_reason: row['ABNExemptReason'] || '',
                indigenous: row['IsATSIOwned'].to_i == 1,
                addresses: [
                  {
                    address: row["Address1"] || '',
                    address_2: row["Address2"] || '',
                    address_3: row["OfficeName"] || '',
                    suburb: row["City"] || '',
                    postcode: row["Postcode"] || '',
                    state: convert_state(row),
                    country: ISO3166::Country.find_country_by_name(
                             row["Country"])&.un_locode || '',
                  }
                ],

                contact_first_name: row["GivenName"] || '',
                contact_last_name: row["Surname"] || '',
                contact_phone: row["CompanyPhone"] || '',
                contact_email: row["Email"].downcase || '',
                contact_position: row["ContactPosition"] || '',

                representative_first_name: row["GivenName"] || '',
                representative_last_name: row["Surname"] || '',
                representative_phone: row["CompanyPhone"] || '',
                representative_email: row["Email"].downcase || '',
                representative_position: row["ContactPosition"] || '',

                number_of_employees: num_emp_h[row["SMEStatus"]] || '',
                australia_employees: num_emp_h[row["SMEStatus"]] || '',
                nsw_employees: num_emp_h[row["SMEStatus"]] || '',
                website_url: row["WebAddress"] || '',
                establishment_date: (
                  Date.parse(row["Date_Established"]).to_s.
                  gsub(/&lt;[^&]*&gt;/, '') rescue ''
                ),
              })
            end

            # import even if registered user is suspended
            # FIXME User is used cross service
            u = ::User.find_by(uuid: row['RegisteredUserUUID'])
            u ||= ::User.find_or_initialize_by(email: row['RegisteredUserEmail'].downcase)
            name = (row['RegisteredUserGivenName'].to_s + ' ' + row['RegisteredUserSurname'].to_s).
              gsub(/[^a-zA-Z0-9 .'\-]/, ' ').gsub(/ +/, ' ').strip
            u.full_name ||= name if name.present?
            u.password = u.password_confirmation = SecureRandom.hex(32) unless u.persisted?

            u.uuid = row['RegisteredUserUUID']
            u.roles << 'seller' unless u.is_seller? || u.is_buyer?
            u.seller_id ||= sv.seller_id
            u.seller_ids |= [sv.seller_id]
            u.grant sv.seller_id, :owner

            u.skip_confirmation_notification!
            u.save!
          end
        rescue => e
          Airbrake.notify_sync(e.message, {
            RUUUID: row['RegisteredUserUUID'],
            PVUUID: row['PanelVendorUUID'],
            trace: e.backtrace.select{|l|l.match?(/buy-nsw/)},
          })
        end
      end
    end
  end
end
