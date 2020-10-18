require_dependency "seller_service/application_controller"

module SellerService
  class SellerProfileFormsController < SellerService::ApplicationController
    include SharedModules::Serializer
    before_action :authenticate_user, only: [:show, :update]
    before_action :set_seller_and_profile, only: [:show, :index, :update]

    def serializer
      SellerService::SellerProfileSerializer.new(profile_version: @profile_version)
    end

    def simple_form_json(seller_id, form_name, form)
      if private_form?(form_name) && !buyer_view?
        {}
      else
        full_sanitize_recursive(form.attributes)
      end
    end

    def form_json(seller_id, form_name, form)
      if private_form?(form_name) && !buyer_view?
        {
          "seller-profile/"+form_name.to_s.dasherize => {
            id: seller_id,
          }
        }
      else
        full_sanitize_recursive(
         { "seller-profile/"+form_name.to_s.dasherize => 
            form.attributes.merge({
              id: seller_id,
            })
         }
        )
      end
    end

    # This action is accessible logged out
    def show
      raise SharedModules::NotFound if @seller.nil? || @profile_version.nil?
      form = form_class(params[:form_name]).new
      form.load @profile_version if @profile_version
      render json: form_json(@seller.id, params[:form_name], form)
    end

    # This action is accessible logged out
    def index
      raise SharedModules::NotFound if @seller.nil? || @profile_version.nil?
      render json: (all_form_names.map { |form_name|
        form = form_class(form_name).new
        form.load @profile_version if @profile_version
        [ form_name, simple_form_json(@seller.id, form_name, form) ]
      }.to_h)
    end

    def update
      key = params.keys.find{|k|k.to_s.starts_with?("sellerProfile/")}
      form = form_class(params[:form_name]).new params[key], @profile_version
      if form.valid?
        @profile_version = @seller.create_profile_version
        form.save(@profile_version)
        @seller.update_search_columns(@profile_version) if params[:form_name].to_sym.in?(
          [:search_description, :company_description]
        )
        render json: form.attributes, status: :created
      else
        render json: { errors: [ form.validation_errors ] }, status: :unprocessable_entity
      end
    end

    private

    def private_form? form_name
      [
        "capability_and_experty",
        "reference_and_case_study",
        "government_credential",
        "team_member",
      ].include? form_name
    end

    def buyer_view?
      return @buyer_view unless @buyer_view.nil?
      return @buyer_view = true if session_user&.is_seller? && @seller&.id && @seller.id == session_user.seller_id
      return @buyer_view = session_user&.can_buy?
    end

    def form_class form_name
      raise SharedModules::NotFound unless form_name.in? all_form_names
      SellerService::Seller::profile_forms[form_name.to_sym]
    end

    def all_form_names
      SellerService::Seller::profile_forms.keys.map(&:to_s)
    end

    def set_seller_and_profile
      if params[:id].present?
        @seller = SellerService::Seller.live.where(id: params[:id]).first
      else
        raise SharedModules::NotAuthorized unless session_user
        raise SharedModules::MethodNotAllowed unless session_user.is_seller? && session_user.seller_id
        @seller = SellerService::Seller.live.where(id: session_user.seller_id).first
      end
      raise SharedModules::NotFound unless @seller
      @profile_version = @seller.last_profile_version
    end
  end
end
