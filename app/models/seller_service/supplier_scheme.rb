module SellerService
  class SupplierScheme < SellerService::ApplicationRecord
    self.table_name = 'supplier_schemes'
    def serialized
      {
        id: self.id,
        title: self.title,
        url: self.url,
        number: self.number,
        category: self.category
      }
    end

    def self.import xml_doc
      rows = xml_doc.css('row').to_a.map do |row|
        fields = row.css("field").map do |field|
          [field['name'], field.inner_text]
        end.compact.to_h
      end

      rows.each do |row|
        scheme = SupplierScheme.find_or_initialize_by(scheme_id: row['SchemeID'].to_s)
        scheme.title = row['Title']
        scheme.start_date = DateTime.parse(row['StartDate'])
        scheme.end_date = DateTime.parse(row['EndDate'])
        scheme.close_date = DateTime.parse(row['RFTCloseDateTime'])
        scheme.rft_uuid = row['RFTUUID']
        scheme.save!
      end
    end
  end
end
