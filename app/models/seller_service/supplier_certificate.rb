require 'rest-client'
require 'json'

module SellerService
  class SupplierCertificate < SellerService::ApplicationRecord
    self.table_name = 'supplier_certificates'

    def self.save_data_from_api
      
      import_date = Time.now
      abo_cert = Certification.where(:cert_display => 'Aboriginal').first_or_create()

      if ENV["SUPPLYNATION_URL"].present?

		  	auth_response = RestClient.post(ENV['SUPPLYNATION_URL'].to_s + '/oauth2/token',{ grant_type: 'password', client_id: ENV['SUPPLYNATION_CLIENT_ID'].to_s, client_secret: ENV['SUPPLYNATION_CLIENT_SECRET'].to_s, username: ENV['SUPPLYNATION_USERNAME'].to_s, password: ENV['SUPPLYNATION_PASSWORD'].to_s }, { content_type: 'application/x-www-form-urlencoded', accept: 'application/json'})
		  	auth_result = JSON.parse(auth_response.to_str)

        next_token = ''

        if abo_cert.update_date.present?
          modified_After = abo_cert.update_date.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        else
          modified_After = 1.year.ago.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
        end


        loop do
          response = RestClient.get(ENV['SUPPLYNATION_URL'].to_s + '/apexrest/impact/public/v3/supplier?modifiedAfter=' + URI::encode(modified_After) + '&next=' + next_token, { Authorization: 'Bearer ' + auth_result['access_token'] })
          cert_data = JSON.parse(response.to_str)

          cert_data['items'].each do |item|
            if item['valid']
              s = SupplierCertificate.find_by(supplier_abn: item['abn'], certification_id: abo_cert.id)
              if s == nil
                s = SupplierCertificate.new
                s.supplier_abn = formatted_abn(item['abn'])
                s.certification_id = abo_cert.id
                s.save
              end
            else
              SupplierCertificate.where(supplier_abn: item['abn'], certification_id: abo_cert.id).destroy_all
            end
          end

          unless cert_data['next'].present?
            break
          else
            next_token = cert_data['next']
          end
        end

        abo_cert.update_date = import_date
        abo_cert.save!

		  end
	  end

	  def self.formatted_abn(abn)
	    abn = (abn || '').gsub(' ', '')

	    abn = abn.insert(2, ' ') if abn.length > 2
	    abn = abn.insert(6, ' ') if abn.length > 6
	    abn = abn.insert(10, ' ') if abn.length > 10

	    abn
	  end

  end
end
