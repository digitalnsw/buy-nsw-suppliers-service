module SellerService
  FactoryBot.define do
    factory :seller, class: SellerService::Seller do
      # NOTE: The following blocks maintain support for passing an owner into the
      # factory (as per the previous behaviour)
      #
      transient do
        owner nil
      end

      # after(:create) do |seller, evaluator|
      #   if evaluator.owner && evaluator.owner.seller_id != seller.id
      #     evaluator.owner.update_attribute(:seller_id, seller.id)
      #   else
      #     create(:seller_user, seller: seller)
      #   end
      # end

      trait :draft do
        state :draft
      end

      trait :deactivated do
        state :deactivated
      end

      trait :live do
        state :live
      end

      factory :active_seller, traits: [:live]
      factory :inactive_seller, traits: [:draft]
      factory :deactivated_seller, traits: [:deactivated]
    end
  end
end
