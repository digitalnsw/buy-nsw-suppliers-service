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

    def attributes(seller)
      profile = seller&.last_profile_version
      if seller
        escape_recursive({
          id: seller.id,
          name: seller.last_version&.name,
          status: seller.status,
          live: seller.live?,
          canBeWithdrawn: seller.can_be_withdrawn?,
          lastProfileUpdate: profile&.updated_at&.strftime("%d %B %Y"),
          lastAccountUpdate: seller.last_version&.updated_at&.strftime("%d %B %Y"),
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
