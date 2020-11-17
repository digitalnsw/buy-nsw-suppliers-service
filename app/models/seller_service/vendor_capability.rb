module SellerService
  class VendorCapability < SellerService::ApplicationRecord
    self.table_name = 'vendor_capabilities'
    scope :current, -> { where("end_date is not null and end_date > ?", Time.now) }

    def serialized
      {
        id: self.id,
        title: self.title,
        abn: self.abn,
      }
    end

    def self.import xml_doc
      rows = xml_doc.css('row').to_a.map do |row|
        fields = row.css("field").map do |field|
          [field['name'], field.inner_text]
        end.compact.to_h
      end

      rows.each do |row|
        begin
          scheme = VendorCapability.find_or_initialize_by(uuid: row['PanelVendorCapabilityUUID'].to_s)
          scheme.abn = ABN.new(row['ABN']).to_s
          next if scheme.abn.blank?
          scheme.title = row['Title']
          scheme.end_date = DateTime.parse(row['EndDate']) rescue nil
          scheme.fields = row
          scheme.save!
        rescue => e
          Airbrake.notify_sync(e.message, {
            PVCUUID: row['PanelVendorCapabilityUUID'],
            trace: e.backtrace.select{|l|l.match?(/buy-nsw/)},
          })
        end
      end
    end
  end
end
