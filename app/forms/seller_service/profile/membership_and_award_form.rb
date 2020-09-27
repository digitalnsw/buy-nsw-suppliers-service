module SellerService::Profile
  class MembershipAndAwardForm < SellerService::BaseForm
    field :awards, type: :json
    field :engagements, type: :json

    validates :awards, 'shared_modules/json': { schema: ['limited?'] }
    validates :engagements, 'shared_modules/json': { schema: ['limited?'] }

    def after_load
      self.awards ||= []
      self.engagements ||= []
    end

    def before_validate
      before_save
    end

    def before_save
      awards.select!(&:present?) if awards.present?
      engagements.select!(&:present?) if engagements.present?
    end
  end
end
