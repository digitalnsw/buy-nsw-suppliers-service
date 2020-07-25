module SellerService
  FactoryBot.define do
    factory :document, class: SellerService::Document do
      document do
        Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'files', 'example.pdf'),
          'application/pdf'
        )
      end
      original_filename 'example.pdf'
      content_type 'application/pdf'

      trait :unscanned do
        scan_status 'unscanned'
      end

      trait :clean do
        after(:create) do |document|
          document.update_attribute(:scan_status, 'clean')
        end
      end

      trait :infected do
        after(:create) do |document|
          document.update_attribute(:scan_status, 'infected')
        end
      end

      factory :unscanned_document, traits: [:unscanned]
      factory :clean_document, traits: [:clean]
      factory :infected_document, traits: [:infected]
    end
  end
end
  