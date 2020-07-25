require_dependency "seller_service/application_controller"

module SellerService
  class PublicSellersController < SellerService::ApplicationController
    before_action :set_seller, only: [:show]

    def serializer
      SellerService::PublicSellerSerializer.new(seller_version: @seller_version,
                                                seller_versions: @seller_versions,
                                                buyer_view: buyer_view)
    end

    def scoped_seller_versions
      SellerService::SellerVersion.approved.yield_self do |rel|
        [
          :category,
          :services,
          :identifiers,
          :locations,
          :company_size,
          :profile,
          :term
        ].reduce(rel) do |rel, filter|
          rel.send("with_" + filter.to_s, params[filter])
        end
      end
    end

    def index
      if params[:current]
        raise SharedModules::NotAuthorized unless session_user
        raise SharedModules::MethodNotAllowed unless session_user.is_seller? && session_user.seller_id
        @seller_version = SellerService::SellerVersion.approved.where(seller_id: session_user.seller_id).first
        raise SharedModules::MethodNotAllowed unless @seller_version
        render json: serializer.show
      else
        if params[:all]
          @seller_versions = scoped_seller_versions
        else
          page = (params[:page] || 1).to_i
          @seller_versions = scoped_seller_versions.
                     order(updated_at: :desc).
                     offset( (page-1) * 25 ).
                     limit(25)
        end
        render json: serializer.index
      end
    end

    def show
      raise SharedModules::NotFound if @seller_version.nil?
      render json: serializer.show
    end

    def custom_scopes filter
      keys = filters.keys + ['category'] - [filter]
      SellerService::SellerVersion.approved.yield_self do |rel|
        keys.reduce(rel) do |rel, filter|
          rel.send("with_" + filter.to_s, params[filter])
        end
      end
    end

    def filters
      {
        services: category_services,
        identifiers: [ "start_up", "disability", "indigenous", "not_for_profit", "regional", "sme", "govdc" ],
        locations: [ "nsw", "au", "nz", "int" ],
        company_size: [ "1to19", "20to49", "50to99", "200plus" ],
        profile: [ "case-studies", "references", "government-projects" ],
      }
    end

    def category_services
      if params[:category].in?(SellerService::SellerVersion.service_levels.keys)
        SellerService::SellerVersion.service_levels[params[:category]]
      else
        SellerService::SellerVersion.service_levels.keys
      end
    end

    def filter_counters
      filters.map do |filter, values|
        [ filter,
          values.map do |value|
            [ value, custom_scopes(filter).send("with_"+filter.to_s, [value]).count ]
          end.to_h
        ]
      end.to_h
    end

    def tag_counters
      [:services, :identifiers].map do |filter|
        [ filter, (params[filter] || []).map do |tag|
            [ tag, custom_scopes(filter).
              send("with_"+filter.to_s, (params[filter] || []) - [tag]).count ]
          end.to_h
        ]
      end.to_h
    end

    def count 
      render json: {
        globalCount: SellerService::SellerVersion.approved.count(:id),
        totalCount: scoped_seller_versions.count(:id),
        filters: filter_counters,
        tags: tag_counters,
      }
    end

    def stats
      render json: {
        pending: SellerService::SellerVersion.pending.count(:id),
        approved: SellerService::SellerVersion.approved.count(:id),
      }
    end

    private

    def buyer_view
      return true if session_user&.is_seller? && @seller_version&.seller_id && @seller_version.seller_id == session_user.seller_id
      if session_user&.is_buyer?
        return session_user && session_user.can_buy?
      end
      return false
    end

    def set_seller
      @seller_version = SellerService::SellerVersion.approved.where(seller_id: params[:id]).first
    end
  end
end
