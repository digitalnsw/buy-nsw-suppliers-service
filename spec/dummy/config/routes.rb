Rails.application.routes.draw do
  mount SellerService::Engine => "/seller_service"
end