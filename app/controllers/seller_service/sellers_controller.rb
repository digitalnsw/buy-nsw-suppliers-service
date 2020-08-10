require_dependency "seller_service/application_controller"

module SellerService
  class SellersController < SellerService::ApplicationController
    skip_before_action :verify_authenticity_token, raise: false, only: [:approve, :decline, :assign]
    before_action :authenticate_service, only: [:approve, :decline, :assign, :destroy]
    before_action :authenticate_service_or_user, only: [:show, :level_2_services]
    before_action :authenticate_user, except: [:show, :level_2_services, :approve, :decline, :assign]
    before_action :set_seller, only: [:show, :update, :destroy, :level_2_services]
    before_action :set_seller_by_id, only: [:approve, :decline, :assign]

    def serializer
      SellerService::SellerSerializer.new(seller: @seller, sellers: @sellers, export_enc: export?, user: session_user)
    end

    def export?
      params[:export_enc].to_s == 'true'
    end

    def create
      raise SharedModules::MethodNotAllowed unless session_user.is_seller?
      if session_user.seller_id
        @seller = SellerService::Seller.where(id: session_user.seller_id).first
      else
        SellerService::Seller.transaction do
          @seller = SellerService::Seller.new(state: :draft)
          @seller.save!
          SharedResources::RemoteUser.update_seller(session_user.id, @seller.id)
          @seller.versions.create!(state: :draft, name: '', started_at: Time.now)
        end
      end
      update_session_attributes(seller_id: @seller.id, seller_status: @seller.status)

      render json: serializer.show, status: :created, location: @seller, root: true
    end

    def schemes
      render json: SellerService::SupplierScheme.all.map(&:serialized)
    end

    def steps
      raise SharedModules::MethodNotAllowed unless session_user&.is_seller? && session_user&.seller_id
      seller = SellerService::Seller.where(id: session_user.seller_id).first
      raise SharedModules::MethodNotAllowed if params[:account] && !seller.live?
      forms = params[:account] ? SellerService::Seller.account_forms : SellerService::Seller.forms
      render json: (forms.map { |k, v|
        form = v.new.load(seller.latest_version)
        [k, {
          status: form.status(seller),
          optional: form.optional?
        }]
      }).to_h
    end

    def alerting_documents
      raise SharedModules::MethodNotAllowed unless session_user.is_seller? && session_user.seller_id
      seller = SellerService::Seller.where(id: session_user.seller_id).first
      raise SharedModules::MethodNotAllowed if seller.nil? || !seller.live?

      service = SellerService::DocumentExpiryService.new(seller_version: seller.latest_version)
      render json: service.documents_serializable
    end

    def destroy
      @seller.destroy
    end

    def index
      if params[:current]
        raise SharedModules::MethodNotAllowed unless session_user&.is_seller?
        @seller = SellerService::Seller.where(id: session_user.seller_id).first
        render json: serializer.show
      else
        render json: {}
      end
    end

    def show
      # THIS MAY BE NEEDED TO MAKE SHOW PAGE WORK
      # set_form
      # @form.prepopulate!
      # @form.validate(params.fetch(:seller_version, {})) if @form.started?
      render json: serializer.show
    end

    def level_2_services
      render json: @seller&.latest_version.level_2_services
    end

    def run_operation(operation)
      set_seller
      @seller.run_action(operation, user: session_user)
      update_session_attributes(seller_status: @seller.status)
      render json: { success: true }
    end

    def run_admin_operation(operation)
      if (operation == :assign)
        @seller.run_action(operation, user: service_user, props: {assignee: {id: params[:assignee][:user_id].to_i, email: params[:assignee][:user_email]}})
      else
        @seller.run_action(operation, user: service_user, props: {field_statuses: params[:field_statuses], response: params[:response]})
      end
    end

    def submit
      run_operation(:submit)
    end

    def cancel
      run_operation(:cancel)
    end

    def withdraw
      run_operation(:withdraw)
    end

    def revise
      run_operation(:revise)
    end

    def start_amendment
      run_operation(:start_amendment)
    end

    def activate
      run_operation(:activate)
    end

    def deactivate
      run_operation(:deactivate)
    end

    def approve
      was_live = @seller.live?
      run_admin_operation(:approve)
      ::SellerApplicationMailer.with(application: @seller.approved_version, was_live: was_live).application_approved_email.deliver_later
      render json: { success: true }
    end

    def decline
      run_admin_operation(:decline)
      ::SellerApplicationMailer.with(application: @seller.declined_version).application_changes_requested_email.deliver_later
      render json: { success: true }
    end

    def assign
      run_admin_operation(:assign)
      render json: { success: true }
    end

    private
    
    def set_seller_by_id
      @seller = SellerService::Seller.where(id: params[:id]).first
    end

    def set_seller
      if service_auth?
        @seller = SellerService::Seller.find_by(id: params[:id])
      elsif params[:id].to_s != session_user.seller_id.to_s
        raise SharedModules::MethodNotAllowed
      else
        raise SharedModules::MethodNotAllowed unless session_user.is_seller? && session_user.seller_id
        @seller = SellerService::Seller.where(id: session_user.seller_id).first
        raise SharedModules::MethodNotAllowed unless @seller
      end
    end

    # Might be needed for show page
    # def set_form
    #   if defined?@form
    #     @form
    #   else
    #     form_name = params[:step].gsub("-", "_").to_sym
    #     raise "Invalid Contract #{params[:step]}" unless form_name.in? SellerService::Seller.form_names
    #     @form = @seller.contracts[form_name].new(@seller.last_version)
    #   end
    # end
  end
end
