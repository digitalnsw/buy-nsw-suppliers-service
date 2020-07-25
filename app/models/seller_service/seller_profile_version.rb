module SellerService
  class SellerProfileVersion < SellerService::ApplicationRecord
    include PgSearch::Model
    pg_search_scope :search_by_term, against: [
      :flagship_product, :summary,
      :accreditations, :licenses, :engagements, :awards,
      :methodologies, :knowledge_base, :quality_control, :security,
      :references, :case_studies, :government_credentials,
      :schemes_and_panels, :team_members 
    ]

    self.table_name = 'seller_profile_versions'
    acts_as_paranoid column: :discarded_at

    belongs_to :seller, class_name: 'SellerService::Seller'
    belongs_to :next_version, class_name: 'SellerService::SellerProfileVersion', optional: true
    has_one :previous_version, class_name: 'SellerService::SellerProfileVersion', foreign_key: :next_version_id
  end
end
