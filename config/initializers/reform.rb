require 'reform'
require "reform/form/dry"

Reform::Form.class_eval do
  feature Reform::Form::Dry
end

require 'dry/validation/compat/form'
# require 'reform'

# Set Reform to use dry-validation instead of ActiveModel validations
#
Rails.application.config.reform.validations = :dry

Dry::Validation::Schema::Form.configure do |config|
  config.messages = :i18n
end

class Reform::Contract::Errors
  def full_messages_for(name)
    @errors[name]
  end
end
