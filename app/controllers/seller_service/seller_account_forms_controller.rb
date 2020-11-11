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
      raise SharedModules::MethodNotAllowed unless @seller.status.in? [:live, :amendment_draft, :amendment_changes_requested, :amendment_pending]
      @seller.run_action(:start_amendment, user: session_user) if @seller.status == :live
      @seller.run_action(:revise, user: session_user) if @seller.status == :amendment_changes_requested
      key = params.keys.find{|k|k.to_s.starts_with?("sellerAccount/")}

      version = @seller.draft_version || @seller.pending_version
      form = form_class.new params[key], version
      form.session_user = session_user

      if form_name.in?([:insurance_document, :financial_document, :legal_disclosure]) &&
          form.status(@seller) == :pending_locked
        raise SharedModules::MethodNotAllowed
      end

      if form.valid?
        form.save(version)
        form.update_field_statuses(@seller)

        @seller.auto_partial_approve_or_submit!(version, session_user)

        UserService::SyncTendersTeamJob.perform_later @seller.id
        render json: serialize(form), status: :created
      else
        render json: { errors: [ form.rejections(@seller).merge(form.validation_errors) ] }, status: :unprocessable_entity
      end
    end

    def index
      show
    end

    def show
      form = form_class.new
      form.session_user = session_user
      form.load @seller.last_version
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
