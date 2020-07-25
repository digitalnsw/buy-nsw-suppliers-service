module SellerService
  class JsonValidator < ActiveModel::EachValidator
    def validate_recursive(value, schema)
      value = value.permit(value.keys).to_h if value.is_a? ActionController::Parameters
      if schema.is_a? Array
        value = value.to_a if value.is_a? Enumerize::Set
        if value.is_a? Array
          value.map.with_index do |v, i|
            [i, validate_recursive(v, schema.first)]
          end.to_h.select{|k,v| v.present?}
        else
          "Expected an array but got a " + value.class.to_s
        end
      elsif schema.is_a? Hash
        if value.is_a? Hash
          return "Missing fields" if schema.keys.length != value.keys.length
          value.map do |k, v|
            [k, validate_recursive(v, schema[k.to_sym])]
          end.to_h.select{|k,v| v.present?}
        else
          "Expected a hash but got a " + value.class.to_s
        end
      elsif schema.is_a? Range
        "Not in range" unless schema.include? value
      elsif schema.is_a? Set
        "Not in allowed list of values" unless schema.include? value
      elsif schema.is_a? Regexp
        "Invalid format" unless schema =~ value
      elsif schema.is_a? NilClass
        "Invalid key"
      elsif schema.is_a? String
        return if schema.ends_with?('?') && value.blank?
        return "This field can't blank" if !schema.ends_with?('?') && value.blank?

        pattern = schema.ends_with?('?') ? schema.chop : schema

        if pattern == 'number'
          "Number expected" unless value.is_a? Numeric
        elsif pattern == 'document'
          @document_ids.push value
          "Document was not accepted" unless value.is_a? Integer
        elsif pattern == 'avatar'
          "Avatar was not accepted" unless value.is_a? Integer
        elsif pattern == 'integer'
          "Integer expected" unless value.is_a? Integer
        elsif pattern == 'string'
          "String expected" unless value.is_a? String
        elsif pattern == 'limited'
          "Invalid format" unless value.is_a?(String) && /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/]{0,100}\z/ =~ value
        elsif pattern == 'name'
          "Invalid name" unless value.is_a?(String) && /\A[A-Za-z .'\-]{0,100}\z/ =~ value
        elsif pattern == 'phone'
          "Phone number expected" unless value.is_a?(String) && /\A(\+)?[0-9 ()\-]{3,20}\z/ =~ value
        elsif pattern == 'email'
          "Email address expected" unless value.is_a?(String) && URI::MailTo::EMAIL_REGEXP =~ value
        elsif pattern == 'text'
          "Invalid format" unless value.is_a?(String) && /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ =~ value
        else
          "Not implemented"
        end
      else
        "Not implemented"
      end
    end

    def validate_each(record, attribute, value)
      @document_ids = []
      validate_recursive(value, options[:schema]).yield_self do |errors|
        record.set_json_error(attribute, errors) if errors.present?
      end
      if @document_ids.present?
        begin
          SharedResources::RemoteDocument.can_attach?(record.seller_id, @document_ids.map(&:to_i))
        rescue ActiveResource::ForbiddenAccess
          record.errors.add(attribute, "Document ownership check failed")
        end
      end
    end
  end
end
