module SellerService
  class BaseForm
    include ActiveModel::Validations
    include SharedModules::Serializer

    attr_accessor :session_user

    # This loads fields from form
    def initialize(fields_hash = {}, version = nil)
      if version
        back_end_fields.each do |field|
          send(field.to_s + '=', version.send(field))
        end
      end
      fields_hash.each do |key, value|
        next unless (two_way_fields + front_end_fields).include?(key.to_sym)
        field_type = field_types[key.to_sym]
        if field_type == :date
          send(key.to_s + "=", (DateTime.parse(value.to_s) rescue nil))
        else
          send(key.to_s + "=", value)
        end
      end
    end

    # This returns fields for form prepopulation
    def attributes
      (two_way_fields + front_end_fields + read_only_fields).map do |field|
        field_type = field_types[field]
        if field_type == :date
          [field, send(field)&.to_date.to_s]
        else
          [field, send(field)]
        end
      end.to_h
    end

    # This saves fields to DB
    def save(version)
      back_end_fields.each do |field|
        send(field.to_s + '=', version.send(field))
      end
      before_save if defined? before_save
      (two_way_fields+back_end_fields).each do |field|
        version.send(field.to_s + '=', send(field)) if version.respond_to?(field.to_s + '=')
      end
      version.save!
    end

    # This loads fields from DB
    def load(version)
      (two_way_fields + back_end_fields + read_only_fields).each do |field|
        send(field.to_s + '=', unescape_recursive(version.send(field)))
      end
      after_load if defined? after_load
      self
    end

    def valid?
      before_validate if defined? before_validate
      super
    end

    def validation_errors
      validation_errors = {}
      fields.each do |field|
        validation_errors[field] = errors.messages[field].first if errors.messages[field].present?
      end
      json_fields.each do |field|
        validation_errors[field] = @json_errors[field] if @json_errors && @json_errors[field].present?
      end
      validation_errors
    end

    def set_json_error attribute, error
      @json_errors ||= {}
      @json_errors[attribute] = error
      errors.add attribute, "JSON validation failed"
    end

    def fields
      self.class.fields
    end

    def self.fields
      @fields || []
    end

    def two_way_fields
      self.class.two_way_fields
    end

    def self.two_way_fields
      fields.select{|f| @field_usages[f] == :two_way}
    end

    def read_only_fields
      self.class.read_only_fields
    end

    def self.read_only_fields
      fields.select{|f| @field_usages[f] == :read_only}
    end

    def front_end_fields
      self.class.front_end_fields
    end

    def self.front_end_fields
      fields.select{|f| @field_usages[f] == :front_end}
    end

    def back_end_fields
      self.class.back_end_fields
    end

    def self.back_end_fields
      fields.select{|f| @field_usages[f] == :back_end}
    end

    def json_fields
      self.class.json_fields
    end

    def self.json_fields
      fields.select{|f| @field_types[f] == :json}
    end

    def field_types
      self.class.field_types
    end

    def self.field_types
      @field_types || {}
    end

    def field_usages
      self.class.field_usages
    end

    def self.field_usages
      @field_usages || {}
    end

    # Valid types: :scalar , :date , :json
    # Valid usages: :two_way, :read_only, :front_end, :back_end
    def self.field field_name, type: :scalar, usage: :two_way, feedback: nil
      feedback = usage == :two_way if feedback.nil?
      raise "field_name must be symbol" unless field_name.is_a? Symbol
      raise "valid types are :scalar , :date , :json" unless type.in? [:scalar , :date , :json]
      raise "valid usages are :two_way, :read_only, :front_end, :back_end" unless usage.in? [:two_way, :read_only, :front_end, :back_end]

      @fields ||= []
      @fields.push field_name

      @field_types ||= {}
      @field_types[field_name] = type

      @field_usages ||= {}
      @field_usages[field_name] = usage

      @feedback_fields ||= []
      @feedback_fields.push field_name if feedback

      attr_accessor field_name
    end
  end
end
