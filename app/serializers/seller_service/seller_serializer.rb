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
      version = seller&.last_version_with_schemes
      if seller
        full_sanitize_recursive({
          id: seller.id,
          name: version&.name,
          abn: version&.abn,
          response: version&.response,
          status: seller.status,
          live: seller.live?,
          canBeWithdrawn: seller.can_be_withdrawn?,
          lastProfileUpdate: profile&.updated_at&.strftime("%d %B %Y"),
          lastProfileEditedBy: profile&.edited_by&.full_name,
          lastAccountUpdate: version&.updated_at&.strftime("%d %B %Y"),
          lastAccountEditedBy: version&.edited_by&.full_name,
          schemes_and_panels: version&.panel_vendors&.select{|p|
            p.scheme.current?
          }.map{|p|
            p.scheme&.serialized&.merge({owned_by: p.email})
          },
          capabilities: version&.capabilities&.current&.uniq&.map(&:serialized),
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
