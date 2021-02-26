require 'rest-client'
require 'json'

module SellerService
  class SupplierCertificate < SellerService::ApplicationRecord
    self.table_name = 'supplier_certificates'

    def self.save_data_from_api

    	if ENV["SUPPLYNATION_URL"].present?
		  	abo_cert = Certification.where(:cert_display => 'Aboriginal').first_or_create(:update_date => Time.now)

		  	auth_response = RestClient.post(ENV['SUPPLYNATION_URL'].to_s + '/oauth2/token',{ grant_type: 'password', client_id: ENV['SUPPLYNATION_CLIENT_ID'].to_s, client_secret: ENV['SUPPLYNATION_CLIENT_SECRET'].to_s, username: ENV['SUPPLYNATION_USERNAME'].to_s, password: ENV['SUPPLYNATION_PASSWORD'].to_s }, { content_type: 'application/x-www-form-urlencoded', accept: 'application/json'})
		  	auth_result = JSON.parse(auth_response.to_str)

				response = RestClient.get(ENV['SUPPLYNATION_URL'].to_s + '/apexrest/impact/public/v3/supplier?modifiedAfter=' + URI::encode('2021-02-01T05:13:31.901Z'), { Authorization: 'Bearer ' + auth_result['access_token'] })
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
