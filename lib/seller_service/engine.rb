module SellerService
  class Engine < ::Rails::Engine
    isolate_namespace SellerService
    config.generators.api_only = true
  end
end
