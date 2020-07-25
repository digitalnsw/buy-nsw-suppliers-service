$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "seller_service/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "seller_service"
  s.version     = SellerService::VERSION
  s.authors     = ["Arman"]
  s.email       = ["arman.sarrafi@customerservice.nsw.gov.au"]
  s.homepage    = ""
  s.summary     = "Summary of SellerService."
  s.description = "Description of SellerService."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
end
