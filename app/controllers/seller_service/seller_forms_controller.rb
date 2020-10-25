require_dependency "seller_service/application_controller"

module SellerService
  class SellerFormsController < SellerService::ApplicationController
    before_action :authenticate_user, only: [:index, :update]
    before_action :set_seller, only: [:index, :update]

    def update
      key = params.keys.find{|k|k.to_s.starts_with?("sellerForm/")}
      form = form_class.new params[key], @seller.draft_version
      form.session_user = session_user
      raise SharedModules::AlertError.new("Invalid form submission, please refresh the page.") if @seller.draft_version.blank?
      form.save(@seller.draft_version)
      form.update_field_statuses(@seller)
      if form.valid?
        UserService::SyncTendersTeamJob.perform_later @seller.id
        render json: form.attributes, status: :created
      else
        render json: { errors: [ form.rejections(@seller).merge(form.validation_errors) ] }, status: :unprocessable_entity
      end
    end

    def index
      form = form_class.new
      form.session_user = session_user
      form.load @seller.last_version
      form.valid?
      render json: {
        "seller-form/"+params[:form_name].to_s => form.attributes.merge({
          id: @seller.id,
          status: form.status(@seller),
          optional: form.optional?,
          apiErrors: form.rejections(@seller).merge(form.validation_errors)
        })
      }
    end

    private

    def form_class
      raise SharedModules::NotFound unless form_name.in? SellerService::Seller::forms.keys
      SellerService::Seller::forms[form_name]
    end

    def form_name
      params[:form_name].gsub("-", "_").to_sym
    end

    def set_seller
      raise SharedModules::MethodNotAllowed unless session_user.is_seller? && session_user.seller_id
      @seller = SellerService::Seller.where(id: session_user.seller_id).first
      raise SharedModules::MethodNotAllowed unless @seller
    end
  end
end
