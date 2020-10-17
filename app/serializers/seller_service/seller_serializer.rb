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
      @schemes = SellerService::SupplierScheme.all.to_a
    end

    def schemes_hash
      @schemes_hash ||= @schemes.map { |scheme|
        [ scheme.id, scheme.serialized ]
      }.to_h
    end

    def attributes(seller)
      profile = seller&.last_profile_version
      version = seller&.last_version
      if seller
        unescape_recursive({
          id: seller.id,
          name: version&.name,
          status: seller.status,
          live: seller.live?,
          canBeWithdrawn: seller.can_be_withdrawn?,
          lastProfileUpdate: profile&.updated_at&.strftime("%d %B %Y"),
          lastAccountUpdate: version&.updated_at&.strftime("%d %B %Y"),
          schemes_and_panels: version&.schemes_and_panels&.map{|s_id| schemes_hash[s_id]}&.compact,
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
