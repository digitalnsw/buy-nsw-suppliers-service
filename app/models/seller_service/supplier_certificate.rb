require 'rest-client'
require 'json'
require 'csv'

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

    def self.import_ade_csv

      import_date = Time.now
      ade_cert = Certification.where(:cert_display => 'Disability').first_or_create()

      # import CSV data
      csv_path = Rails.root.join('csv', 'ade-certified.csv').to_s
      table = CSV.parse(File.read(csv_path), headers: true)
      
      table.each do |row|
        s = SupplierCertificate.find_by(supplier_abn: row['abn'], certification_id: ade_cert.id)
        if s == nil
          s = SupplierCertificate.new
          s.supplier_abn = formatted_abn(row['abn'])
          s.certification_id = ade_cert.id
          s.created_at = import_date
          s.updated_at = import_date
          s.save
        end
      end

      # clean up old data
      SupplierCertificate.where("certification_id = ? AND created_at < ?", ade_cert.id, import_date).destroy_all

    end

    def self.import_social_csv

      import_date = Time.now
      social_cert = Certification.where(:cert_display => 'Social').first_or_create()

      # import CSV data
      csv_path = Rails.root.join('csv', 'social-certified.csv').to_s
      table = CSV.parse(File.read(csv_path), headers: true)
      
      table.each do |row|
        s = SupplierCertificate.find_by(supplier_abn: row['abn'], certification_id: social_cert.id)
        if s == nil
          s = SupplierCertificate.new
          s.supplier_abn = formatted_abn(row['abn'])
          s.certification_id = social_cert.id
          s.created_at = import_date
          s.updated_at = import_date
          s.save
        end
      end

      # clean up old data
      SupplierCertificate.where("certification_id = ? AND created_at < ?", social_cert.id, import_date).destroy_all

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
