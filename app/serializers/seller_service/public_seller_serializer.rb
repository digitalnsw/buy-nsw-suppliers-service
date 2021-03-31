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
      cert_disability = SellerService::Certification.find_by(cert_display: 'Disability')
      cert_indigenous = SellerService::Certification.find_by(cert_display: 'Aboriginal')
      cert_social_enterprise = SellerService::Certification.find_by(cert_display: 'Social')
      result = {
        id: version.seller_id,
        tags: {
          regional: 'Regional',
          start_up: 'Startup',
          sme: 'SME',
          not_for_profit: 'Not for profit',
          # disability: 'Disability',
          australian_owned: 'Australian owned',
          govdc: 'GovDC',
          disability_verified: 'Disability',
          indigenous: 'Aboriginal',
          indigenous_verified: 'Aboriginal Verified',
          social_enterprise_verified: 'Social enterprise'
        }.map{ |key, value| 
          if key.equal? :disability_verified
            if version.send(:disability_optout).present? || !cert_disability.present?
              nil
            else
              version&.supplier_certificates&.where(certification_id: cert_disability.id).count > 0 ? value : nil
            end
          elsif key.equal? :indigenous_verified
            if !cert_indigenous.present?
              nil
            else
              version&.supplier_certificates&.where(certification_id: cert_indigenous.id).count > 0 ? value : nil
            end  
          elsif key.equal? :social_enterprise_verified
            if version.send(:social_enterprise_optout).present? || !cert_social_enterprise.present?
              nil
            else
              version&.supplier_certificates&.where(certification_id: cert_social_enterprise.id).count > 0 ? value : nil
            end  
          else
            version.send(key) ? value : nil 
          end
        }.compact,
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
        schemes_and_panels: version&.panel_vendors&.select{|p|
          p.scheme.current?
        }.map{|p|
          p.scheme&.serialized&.merge({
            panel_vendor_uuid: p.uuid
          })
        },
        capabilities: version&.capabilities&.current&.uniq&.map(&:serialized),
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

      # remove 'Aboriginal' from tags if 'Aboriginal Verified' is set
      result[:tags].delete('Aboriginal') if result[:tags].include?('Aboriginal Verified')
      # remove 'Aboriginal Verified' from tags if indigenous_optout is set
      result[:tags].delete('Aboriginal Verified') if version.send(:indigenous_optout).present?

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
