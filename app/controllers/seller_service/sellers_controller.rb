require_dependency "seller_service/application_controller"

module SellerService
  class SellersController < SellerService::ApplicationController
    skip_before_action :verify_authenticity_token, raise: false, only: [:approve, :decline, :assign]
    before_action :authenticate_service, only: [:approve, :decline, :assign, :destroy]
    before_action :authenticate_service_or_user, only: [:show, :all_services]
    before_action :authenticate_user, except: [:show, :all_services, :approve, :decline, :assign, :join]
    before_action :set_seller, only: [:show, :update, :destroy, :all_services]
    before_action :set_seller_by_id, only: [:approve, :decline, :assign]

    def serializer
      SellerService::SellerSerializer.new(seller: @seller, sellers: @sellers, export_enc: export?, user: session_user)
    end

    def export?
      params[:export_enc].to_s == 'true'
    end

    def create
      raise SharedModules::MethodNotAllowed unless session_user.is_seller?

      SellerService::Seller.transaction do
        @seller = SellerService::Seller.new(state: :draft)
        @seller.save!
        SharedResources::RemoteUser.add_to_team(session_user.id, @seller.id, [:owner])
        @seller.versions.create!(state: :draft, name: '', started_at: Time.now)
      end

      update_session_user(seller_id: @seller.id, seller_status: @seller.status)

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
        form = v.new.load(seller.last_version)
        form.session_user = session_user
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

      service = SellerService::DocumentExpiryService.new(seller_version: seller.last_version)
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
      elsif params[:myProfiles]
        @sellers = SellerService::Seller.where(id: session_user&.seller_ids)
        render json: serializer.index
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

    def all_services
      render json: @seller&.last_version.services
    end

    def run_operation(operation)
      set_seller
      @seller.run_action(operation, user: session_user)
      update_session_user(seller_status: @seller.status)
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
      UserService::SyncTendersTeamJob.perform_later @seller.id
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

    def join
      abn = ABN.new(params[:abn]).to_s
      sv = SellerService::SellerVersion.where(state: ['approved', 'pending'], abn: abn).
        where.not(seller_id: session_user.seller_ids).first

      raise SharedModules::AlertError.new('Invalid ABN!') if abn.blank?

      raise SharedModules::AlertError.new('Your join request was not sent! Are you already a member?') if sv.blank?

      owners = SharedResources::RemoteUser.get_owners(sv.seller_id)

      raise SharedModules::AlertError.new('Your join request was not sent. There is no one to approve it!') if owners.empty?

      SharedResources::RemoteNotification.create_notification(
        unifier: 'join_' + session_user.id.to_s + '_to_' + sv.seller_id.to_s,
        recipients: owners.map(&:id),
        subject: "#{current_user.email} has requested to join your team",
        body: "By accepting this request #{current_user.full_name || current_user.email} will be able to make changes to your company account and profile.",
        fa_icon: 'user-clock',
        actions: [
          {
            key: 'accept',
            caption: 'Accept',
            resource: 'remote_user',
            method: 'add_to_team',
            params: [session_user.id, sv.seller_id],
            success_message: 'join_request_accepted',
          },
          {
            key: 'decline',
            caption: 'Decline',
            button_class: 'button-secondary',
            success_message: 'join_request_declined',
          },
        ]
      )

      SharedResources::RemoteEvent.generate_token current_user
      SharedResources::RemoteEvent.create_event(
          current_user.id, 'User',
          current_user.id, 'Event::User',
          'User requested to join supplier: ' + sv.seller_id.to_s)

      render json: {}, status: :created
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
