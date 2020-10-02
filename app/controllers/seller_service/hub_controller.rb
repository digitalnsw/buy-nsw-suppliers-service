require_dependency "seller_service/application_controller"

module SellerService
  class HubController < SellerService::ApplicationController
    before_action :authenticate_jwt

    def serializer
      SellerService::SellerHubSerializer.new(seller_version: @seller_version,
                                             seller_versions: @seller_versions)
    end

    def scoped_seller_versions
      SellerService::SellerVersion.approved.yield_self do |rel|
        [
          :phrase,
          :abn,
          :contact_name,
          :business_name,
        ].reduce(rel) do |rel, filter|
          rel.send("with_" + filter.to_s, params[filter])
        end
      end
    end

    def count
      render json: { count: scoped_seller_versions.count }
    end

    def index
      page = (params[:page] || 1).to_i
      ppr = (params[:ppr] || 100).to_i

      @seller_versions = scoped_seller_versions.

      if params[:order] == 'abn'
        @seller_versions = scoped_seller_versions.order(:abn)
      elsif params[:order] == 'contact_name'
        @seller_versions = scoped_seller_versions.order(:contact_first_name, :contact_last_name)
      elsif params[:order] == 'business_name'
        @seller_versions = scoped_seller_versions.order(:name)
      end

      render json: serializer.index
    end

    def show
      @seller_version = SellerService::SellerVersion.approved.
                        find_by(seller_id: params[:id].to_i)
      raise SharedModules::NotFound if @seller_version.nil?
      render json: serializer.show
    end
  end
end
