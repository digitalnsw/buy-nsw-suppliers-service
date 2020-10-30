module SellerService
  class PublicSellerSerializer
    include SharedModules::Serializer
    def initialize(seller_version: nil, seller_versions: nil, buyer_view: false)
      @buyer_view = buyer_view
      @seller_version = seller_version
      @seller_versions = seller_versions
    end

    def attributes(version)
      profile = version.last_profile_version
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
          govdc: 'GovDC',
        }.map{ |key, value| version.send(key) ? value : nil }.compact,
        level_1_services: version.level_1_services,
        level_2_services: version.level_2_services,
        level_3_services: version.level_3_services,
        documents: [
          "financial_statement",
          "professional_indemnity_certificate",
          "workers_compensation_certificate",
          "product_liability_certificate",
        ].select{|field| version.send(field+"_ids").present?}.map{ |field|
          {
            ids: version.send(field+"_ids"),
            name: field.humanize,
          }
        },
        schemes_and_panels: version.schemes.current.uniq.map(&:serialized),
      }.merge(full_sanitize_recursive version.attributes.slice(
        "name",
        "abn",
      )).merge(full_sanitize_recursive({
        public_address: version.addresses[version.profile_address_index],
        updated_at: profile&.updated_at&.strftime("%d %B %Y"),
        flagship_product: profile&.flagship_product,
        website_url: profile&.website_url,
        summary: profile&.summary,
      }))
      if @buyer_view
        result.merge!(full_sanitize_recursive version.attributes.slice(
          "contact_first_name",
          "contact_last_name",
          "contact_phone",
          "contact_email",
          "contact_position",
        ))
      end

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
