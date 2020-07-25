require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require "seller_service"

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '*.yml')]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.yml')]
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '**', '*.yml')]

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
