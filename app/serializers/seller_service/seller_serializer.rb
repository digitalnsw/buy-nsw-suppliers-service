require 'openssl'
require 'base64'

module SellerService
  class SellerSerializer
    include SharedModules::Serializer

    def initialize(seller: nil, sellers: nil, export_enc: false, user: nil)
      @user = user
      @seller = seller
      @export_enc = export_enc
      @sellers = sellers
    end

    def export_params(user, version)
      {
        firstname: user.full_name&.split(' ')&.first || '',
        surname: user.full_name&.split(' ')&.last || '',
        email: user.email,
        title: '',
        companyName: version.name || '',
        tradingName: version.name || '',
        "ABN": version.abn || '',
        companyPhone: version.contact_phone || '',
        mobilePhone: version.contact_phone || '',
        address: {
          addressLine1: version.addresses&.first['address'] || '',
          addressLine2: version.addresses&.first['address_2'] || '',
          city: version.addresses&.first['suburb'] || '',
          state: version.addresses&.first['state']&.upcase || '',
          postcode: version.addresses&.first['postcode'] || '',
          country: (ISO3166::Country.new(version.addresses&.first['country']).name.upcase rescue '')
        }
      }
    end

    def bin2hex(data)
      data.unpack('C*').map{ |b| "%02X" % b }.join('')
    end

    def blowfish(data)
      cipher = OpenSSL::Cipher.new('bf-ecb').encrypt
      cipher.key = Base64.decode64(ENV['ETENDERING_ENCRYPTION_KEY'])
      cipher.update(data) << cipher.final
    end

    def attributes(seller)
      profile = seller&.last_profile_version
      if seller
        escape_recursive({
          id: seller.id,
          name: seller.latest_version&.name,
          status: seller.status,
          live: seller.live?,
          offersCloud: seller.approved_version&.services&.include?('cloud-services') ||
                       seller.approved_version&.govdc? || seller.approved_version&.offers_cloud?,
          offersTelco: seller.approved_version&.services&.include?('telecommunications'),
          canBeWithdrawn: seller.can_be_withdrawn?,
          lastProfileUpdate: profile&.updated_at&.strftime("%d %B %Y"),
          lastAccountUpdate: seller.latest_version&.updated_at&.strftime("%d %B %Y"),
          owner_id: seller.owner_id,
          export_enc: @export_enc && seller.live? && bin2hex(blowfish(export_params(@user, seller.approved_version).to_json))
        })
      end
    end

    def show
      { seller: attributes(@seller) }
    end

    def index
      {
        sellers: @sellers.map do |seller|
          attributes(seller)
        end
      }
    end
  end
end
