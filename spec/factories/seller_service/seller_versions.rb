module SellerService
  FactoryBot.define do
    factory :seller_version, class: SellerService::SellerVersion do
      association :seller
      draft

      transient do
        owner nil
      end

      after(:create) do |seller_version, evaluator|
        if evaluator.owner && seller_version.seller.present?
          evaluator.owner.update_attribute(:seller_id, seller_version.seller.id)
        end
      end

      trait :with_tailor_fields do
        offers_ict true
        offers_cloud true
        name 'Seller Ltd'
        establishment_date 1.year.ago
        summary 'We sell things'
        flagship_product 'We sell things'
        abn
        website_url 'http://example.org'
        linkedin_url 'http://linkedin.com/example'
        services ['cloud-services']
      end

      trait :with_full_seller_profile do
        with_tailor_fields

        govdc true

        annual_turnover '3m-10m'
        number_of_employees '2to4'
        nsw_employees '2to4'
        australia_employees '2to4'
        corporate_structure 'standalone'
        business_structure 'sole-trader'
        start_up true
        regional true
        state_government_experience true

        contact_first_name 'Seller'
        contact_last_name 'Sellerton'
        contact_email 'seller@example.org'
        contact_phone '02 9123 4567'
        contact_position 'Signer'

        representative_first_name 'Signy'
        representative_last_name 'Signerton'
        representative_email 'signy@example.org'
        representative_phone '02 9765 4321'
        representative_position 'Signer'

        accreditations []
        accreditation_document_ids []
        engagements [
          "Board member, Australian Bakers' Association",
        ]
        sequence(:awards) do |n|
          ["Baker of the year #{2010 + n}"]
        end

        addresses do
          [attributes_for(:seller_address)]
        end

        receivership false
        bankruptcy false
        investigations false
        legal_proceedings false
        insurance_claims false
        conflicts_of_interest false
        other_circumstances false

        product_liability_certificate_ids []
        product_liability_certificate_expiry { Date.tomorrow.to_s }

        financial_statement_ids []
        financial_statement_expiry 1.year.from_now
        financial_statement_agree true

        professional_indemnity_certificate_ids []
        professional_indemnity_certificate_expiry { (Date.tomorrow + 5.months).to_s }

        workers_compensation_nonexempt false
        workers_compensation_nonexempt_details 'exempt'

        agree true
      end

      trait :with_active_seller do
        association :seller, factory: :active_seller
      end

      trait :draft do
        state 'draft'
        started_at { Time.now }
      end

      trait :awaiting_assignment do
        state 'pending'

        with_full_seller_profile
      end

      trait :ready_for_review do
        state 'pending'
        assigned_to_id 1 

        with_full_seller_profile
      end

      trait :approved do
        state 'approved'
        response 'Well done!'
        assigned_to_id 1


        with_full_seller_profile
        with_active_seller
      end

      trait :returned_to_applicant do
        state 'declined'
        response 'Almost there!'
        assigned_to_id 1

        with_full_seller_profile
      end

      trait :archived do
        state 'archived'
        discarded_at { Time.now }
        assigned_to_id 1

        with_full_seller_profile
      end

      factory :created_seller_version, traits: [:draft]
      factory :created_seller_version_with_profile, traits: [:draft, :with_full_seller_profile]
      factory :awaiting_assignment_seller_version, traits: [:awaiting_assignment]
      factory :ready_for_review_seller_version, traits: [:ready_for_review]
      factory :approved_seller_version, traits: [:approved]
      factory :archived_seller_version, traits: [:archived]
      factory :returned_to_applicant_seller_version, traits: [:returned_to_applicant]
    end
  end
end
