module SellerService
  class SellerHubSerializer
    include SharedModules::Serializer
    def initialize(seller_version: nil, seller_versions: nil)
      @seller_version = seller_version
      @seller_versions = seller_versions
      @schemes = SellerService::SupplierScheme.all.to_a
    end

    def schemes_hash
      @schemes_hash ||= @schemes.map { |scheme|
        [ scheme.id, scheme.serialized ]
      }.to_h
    end

    def attributes(version)
      profile = version.seller.last_profile_version

      result = {
        id: version.seller_id,
        tags: {
          regional: 'Regional',
          start_up: 'Startup',
          sme: 'SME',
          indigenous: 'Aboriginal',
          not_for_profit: 'Not for profit',
          disability: 'Disability',
          australian_owned: 'Australian owned',
        }.map{ |key, value| version.send(key) ? value : nil }.compact,
        public_address: version.addresses[version.profile_address_index],
        schemes_and_panels: version.schemes_and_panels&.map{|s_id| schemes_hash[s_id]}.compact,
      }.merge(escape_recursive version.attributes.slice(
        "name",
        "abn",
        "contact_first_name",
        "contact_last_name",
        "contact_phone",
        "contact_email",
        "contact_position",
        "level_1_services",
        "level_2_services",
        "level_3_services",
      )).merge(escape_recursive({
        updated_at: profile&.updated_at&.strftime("%d %B %Y"),
        flagship_product: profile&.flagship_product,
        website_url: profile&.website_url,
        summary: profile&.summary,
      }))

      result
    end

    def show
      { publicSeller: attributes(@seller_version) }
    end

    def index
      {
        publicSellers: @seller_versions.map do |version|
          attributes(version)
        end
      }
    end
  end
end
