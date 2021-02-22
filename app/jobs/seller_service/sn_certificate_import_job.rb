module SellerService
  class SNCertificateImportJob < SharedModules::ApplicationJob
    def perform 
      SellerService::SupplierCertificate.save_data_from_api()
    end
  end
end
