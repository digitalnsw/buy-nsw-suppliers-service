SellerService::Engine.routes.draw do
  resources :sellers do
    get :steps, on: :collection
    get :alerting_documents, on: :collection
    get :companies, on: :collection
    get :all_services, on: :member
    post :submit, on: :member
    post :cancel, on: :member
    post :withdraw, on: :member
    post :revise, on: :member
    post :assign, on: :member
    post :approve, on: :member
    post :decline, on: :member
    post :start_amendment, on: :member
    post :activate, on: :member
    post :deactivate, on: :member
    get :active_sellers, on: :collection
    get :schemes, on: :collection
  end

  resources :seller_forms, only: [:update, :index], path: "seller_form/:form_name"
  resources :seller_account_forms, only: [:update, :index, :show], path: "seller_account_form/:form_name"
  resources :seller_profile_forms, only: [:update, :show], path: "seller_profile_form/:form_name"
  get 'seller_profile_form/:form_name', to: 'seller_profile_forms#show'
  get 'seller_profile_forms/:id', to: 'seller_profile_forms#index'
  get 'seller_profile_forms', to: 'seller_profile_forms#index'

  resources :public_sellers, only: [:index, :show] do
    get :sub_categories, on: :collection
    get :top_categories, on: :collection
    get :count, on: :collection
    get :stats, on: :collection
  end

  resources :waiting_sellers, only: [] do
    post :initiate_seller, on: :member
    get :find_by_token, on: :collection
  end
end
