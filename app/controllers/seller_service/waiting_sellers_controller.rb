require_dependency "seller_service/application_controller"

module SellerService
  class WaitingSellersController < SellerService::ApplicationController
    skip_before_action :verify_authenticity_token, raise: false, only: [:initiate_seller]
    before_action :authenticate_service, only: [:find_by_token, :initiate_seller]

    def find_by_token
      s = SellerService::WaitingSeller.where(invitation_token: params[:token]).first

      raise SharedModules::NotFound if s.nil?

      render json: {
        waiting_seller: {
          id: s.id,
          contact_name: s.contact_name,
          email: s.contact_email,
          abn: s.abn,
          state: s.invitation_state,
          seller_id: s.seller_id,
          invitation_token: s.invitation_token,
          invited_at: s.invited_at,
          joined_at: s.joined_at,
          created_at: s.created_at,
          updated_at: s.updated_at,
        }
      }
    end

    def initiate_seller
      s = SellerService::WaitingSeller.where(id: params[:id]).first
      s.create_seller!
      raise SharedModules::NotFound if s.nil?
      render json: { seller_id: s.seller.id }
    end
  end
end
