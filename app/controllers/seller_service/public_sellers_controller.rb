require_dependency "seller_service/application_controller"

module SellerService
  class PublicSellersController < SellerService::ApplicationController
    before_action :set_seller, only: [:show]

    def serializer
      SellerService::PublicSellerSerializer.new(seller_version: @seller_version,
                                                seller_versions: @seller_versions,
                                                buyer_view: buyer_view)
    end

    def clear_params
      params[:category] = nil unless SellerService::SellerVersion.level_1_and_2_services.include?(params[:category])
      params[:services] = (params[:services]&.to_a || []) & SellerService::SellerVersion.all_services
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
          clear_params
          page = (params[:page] || 1).to_i

          if params[:order] == 'AtoZ'
            @seller_versions = scoped_seller_versions.order(:name)
          elsif params[:order] == 'ZtoA'
            @seller_versions = scoped_seller_versions.order(name: :desc)
          else
            @seller_versions = scoped_seller_versions.
                     joins(seller: :last_profile_version).
                     order('seller_profile_versions.updated_at' => :desc)
          end

          @seller_versions = @seller_versions.
                     offset( (page-1) * 10 ).
                     limit(10)
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
      # FIXME: Below line is added for early release
      params[:category] = 'information-technology' if params[:category].blank?
      if params[:category].in?(SellerService::SellerVersion.level_1_services)
        SellerService::SellerVersion.service_levels[params[:category]].keys
      elsif params[:category].in?(SellerService::SellerVersion.level_2_services)
        super_cat = SellerService::SellerVersion.super_category params[:category]
        SellerService::SellerVersion.service_levels[super_cat][params[:category]]
      else
        SellerService::SellerVersion.level_1_services
      end
    end

    def filter_counters
      filters.map do |filter, values|
        [ filter,
          values.map do |value|
            [ value, SellerService::SellerVersion.approved.with_category(params[:category]).
              send("with_"+filter.to_s, [value]).count ]
          end.to_h
        ]
      end.to_h
    end

    def count 
      clear_params
      render json: {
        globalCount: SellerService::SellerVersion.approved.count(:id),
        totalCount: scoped_seller_versions.count(:id),
        filters: filter_counters,
      }
    end

    def stats
      render json: {
        pending: SellerService::SellerVersion.pending.count(:id),
        approved: SellerService::SellerVersion.approved.count(:id),
      }
    end

    def top_categories
      # FIXME: Below line is commented for early release
      # l = SellerService::SellerVersion.service_levels.keys
      l = SellerService::SellerVersion.service_levels['information-technology'].keys
      render json: l.map{|k| {key: k, label: 'friendly'}}
    end

    def sub_categories
      render json: SellerService::SellerVersion.flat_sub_categories
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
