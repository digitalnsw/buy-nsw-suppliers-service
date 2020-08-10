module SellerService
  class MembershipAndAwardForm < SellerService::AuditableForm
    field :awards, type: :json
    field :engagements, type: :json

    validates :awards, 'shared_modules/json': { schema: ['limited?'] }
    validates :engagements, 'shared_modules/json': { schema: ['limited?'] }

    def after_load
      self.awards ||= []
      self.engagements ||= []
      while awards.size < 2
        awards.push ''
      end
      while engagements.size < 2
        engagements.push ''
      end
    end

    def before_validate
      before_save
    end

    def before_save
      awards.select!(&:present?) if awards.present?
      engagements.select!(&:present?) if engagements.present?
    end

    def optional?
      true
    end
  end
end
