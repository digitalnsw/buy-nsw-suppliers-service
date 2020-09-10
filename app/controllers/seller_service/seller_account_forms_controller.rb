require_dependency "seller_service/application_controller"

module SellerService
  class SellerAccountFormsController < SellerService::ApplicationController
    before_action :authenticate_user
    before_action :set_seller

    def serialize form
      {
        "seller-account/"+params[:form_name].to_s => form.attributes.merge({
          id: @seller.id,
          status: form.status(@seller),
          apiErrors: form.rejections(@seller).merge(form.validation_errors)
        })
      }
    end

    def update
      raise SharedModules::MethodNotAllowed unless @seller.status.in? [:live, :amendment_draft, :amendment_changes_requested]
      @seller.run_action(:start_amendment, user: session_user) if @seller.status == :live
      @seller.run_action(:revise, user: session_user) if @seller.status == :amendment_changes_requested
      key = params.keys.find{|k|k.to_s.starts_with?("sellerAccount/")}
      form = form_class.new params[key], @seller.draft_version
      if form.valid?
        render json: serialize(form), status: :created
        form.save(@seller.draft_version)
        form.update_field_statuses(@seller)

        UserService::SyncTendersJob.perform_later current_user.id
      else
        render json: { errors: [ form.rejections(@seller).merge(form.validation_errors) ] }, status: :unprocessable_entity
      end
    end

    def index
      show
    end

    def show
      form = form_class.new
      form.load @seller.latest_version
      form.valid?
      render json: serialize(form)
    end

    private

    def form_class
      raise "Invalid form name #{form_name}" unless form_name.in? SellerService::Seller::account_forms.keys
      SellerService::Seller::account_forms[form_name]
    end

    def form_name
      params[:form_name].gsub("-", "_").to_sym
    end

    def set_seller
      raise SharedModules::MethodNotAllowed unless session_user&.is_seller? && session_user.seller_id
      @seller = SellerService::Seller.where(id: session_user.seller_id).first
      raise SharedModules::MethodNotAllowed unless @seller
    end
  end
end
