module SellerService
  class ContactDetailForm < SellerService::AuditableForm
    field :contact_first_name
    field :contact_last_name
    field :contact_email
    field :contact_phone

    field :representative_first_name
    field :representative_last_name
    field :representative_email
    field :representative_phone
    field :representative_position
    field :regional
    field :corporate_structure

    field :same_as_above, usage: :front_end

    field :addresses, type: :json

    validates :contact_first_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_last_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :contact_phone, format: { with: /\A(\+)?[0-9 ()\-]{3,20}\z/ }
    validates :representative_first_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :representative_last_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :representative_email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :representative_phone, format: { with: /\A(\+)?[0-9 ()\-]{3,20}\z/ }
    validates :representative_position, format: { with: /\A[A-Za-z .'\-]+\z/ }

    validates :addresses, 'seller_service/json': { schema:
      [
        {
          address: 'limited',
          address_2: 'limited?',
          address_3: 'limited?',
          suburb: 'limited',
          postcode: 'limited',
          state: 'limited',
          country: 'limited',
        }
      ]
    }

    def postcode_in_regional_range
      postcode = addresses.present? && addresses.first['postcode']&.to_i
      return postcode.present? && (
         2250 <= postcode && postcode <= 2251 ||
         2256 <= postcode && postcode <= 2263 ||
         2311 <= postcode && postcode <= 2312 ||
         2328 <= postcode && postcode <= 2411 ||
         2415 == postcode ||
         2420 <= postcode && postcode <= 2490 ||
         2536 <= postcode && postcode <= 2551 ||
         2575 <= postcode && postcode <= 2594 ||
         2618 <= postcode && postcode <= 2739 ||
         2787 <= postcode && postcode <= 2898)
    end

    def country_is_au_nz
      country = addresses.present? && addresses.first['country'].upcase
      country == 'AU' || country == 'NZ'
    end

    def after_load
      self.same_as_above = false
      if addresses.blank?
        self.addresses = [{"suburb"=>"", "address"=>"", "address_2"=>"", "address_3"=>"", "postcode"=>"", "country"=>"", "state"=>""}]
      end
      country = addresses.present? && addresses.first['country'].upcase
      self.regional = false unless postcode_in_regional_range && country == 'AU'
    end

    def before_save
      self.representative_email.downcase! if representative_email.present?
      self.contact_email.downcase! if contact_email.present?
      addresses.each do |address|
        ["suburb", "address", "address_2", "address_3", "postcode", "country", "state"].each do |field|
          address[field] = '' if address[field].nil?
        end
      end
      if same_as_above.present?
        self.representative_first_name = self.contact_first_name
        self.representative_last_name = self.contact_last_name
        self.representative_email = self.contact_email
        self.representative_phone = self.contact_phone
      end
      country = addresses.present? && addresses.first['country'].upcase
      self.regional = false unless postcode_in_regional_range && country == 'AU'
    end

    def started?
      [
        :contact_first_name,
        :contact_last_name,
        :contact_email,
        :contact_phone,
        :representative_first_name,
        :representative_last_name,
        :representative_email,
        :representative_phone,
        :representative_position,
      ].any? do |field|
        send(field).present? || send(field) == false
      end
    end
  end
end
