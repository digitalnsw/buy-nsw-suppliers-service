module SellerService
  class SellerHubSerializer
    include SharedModules::Serializer
    def initialize(seller_version: nil, seller_versions: nil)
      @seller_version = seller_version
      @seller_versions = seller_versions
    end

    def attributes(version)
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
      }.merge(escape_recursive version.attributes.slice(
        "name",
        "abn",
        "services",
        "contact_first_name",
        "contact_last_name",
        "contact_phone",
        "contact_email",
        "contact_position",
      ))

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
