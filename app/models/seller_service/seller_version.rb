module SellerService
  class SellerVersion < SellerService::ApplicationRecord
    self.table_name = 'seller_versions'
    include AASM
    extend Enumerize

    include Concerns::StateScopes
    include Concerns::Documentable
    include PgSearch::Model
    pg_search_scope :search_by_term, against: [:name, :flagship_product, :summary]

    acts_as_paranoid column: :discarded_at

    before_save :normalise_abn

    before_create :set_time_stamps
    before_save :set_time_stamps

    attr_accessor :skip_timestamps

    def set_time_stamps
      return if skip_timestamps
      self.created_on = DateTime.now if self.new_record?
      self.updated_on = DateTime.now
    end

    alias_attribute :created_at, :created_on
    alias_attribute :updated_at, :updated_on

    belongs_to :seller, class_name: "SellerService::Seller", inverse_of: :versions

    belongs_to :next_version, class_name: 'SellerService::SellerVersion', optional: true, inverse_of: :previous_version
    has_one :previous_version, class_name: 'SellerService::SellerVersion', foreign_key: :next_version_id, inverse_of: :next_version
    has_many :profile_versions, through: :seller
    has_one :last_profile_version, through: :seller


    validates :started_at, presence: true

    belongs_to :edited_by, class_name: 'User', optional: true

    aasm column: :state do
      state :draft, initial: true
      state :pending
      state :declined
      state :approved
      state :deactivated
      state :archived

      event :submit do
        transitions from: :draft, to: :pending
        before do
          self.submitted_at = Time.now
        end
      end

      event :cancel do
        transitions from: :draft, to: :archived
      end

      event :withdraw do
        transitions from: :pending, to: :draft
      end

      event :decline do
        transitions from: :pending, to: :declined
      end

      event :revise do
        transitions from: :declined, to: :draft
      end

      event :approve do
        transitions from: :pending, to: :approved
      end

      event :deactivate do
        transitions from: :approved, to: :deactivated
      end

      event :activate do
        transitions from: :deactivated, to: :approved
      end

      event :archive do
        transitions from: [:pending, :approved], to: :archived
      end
    end

    def version
      day_count = seller.versions.where(
        'started_at BETWEEN ? and ?',
        started_at.beginning_of_day,
        started_at
      ).count
      started_at.strftime("%y.%m.%d.") + day_count.to_s
    end

    def assignee_present?
      assigned_to_id.present?
    end

    def unassigned?
      !assignee_present?
    end

    def may_assign?
      seller.valid_actions.include?(:assign)
    end

    def read_abn
      abn
    end

    def has_approved_version?
      seller.approved_version.present?
    end

    def no_approved_versions?
      !has_approved_version?
    end

    def changed_fields(rhs: previous_version)
      # https://stackoverflow.com/a/43864734/10377598
      if rhs.nil?
        return []
      end
      (attributes.to_a - rhs.attributes.to_a).map { |a| a.first.to_sym }
    end

    def changed_fields_unreviewed
      if !state.to_sym.in?([:draft, :pending])
        return []
      end
      changed_fields
    end

    def all_events
      seller.events
    end

    def self.ranked
      from <<-SQL.strip_heredoc
        (SELECT *, row_number() OVER (
        PARTITION BY seller_id
        ORDER BY id DESC
        ) FROM seller_versions
        WHERE state<>'archived') AS seller_versions
        SQL
    end

    scope :latest, -> { ranked.where('seller_versions.row_number = 1') }

    scope :for_review,        ->            { where(state: :pending) }

    scope :unassigned,        ->            { where('assigned_to_id IS NULL') }
    scope :assigned,          ->            { where('assigned_to_id IS NOT NULL') }
    scope :assigned_to,       -> (user)     { where('assigned_to_id = ?', user) }

    scope :govdc,             ->            { where(govdc: true) }
    scope :not_stale,         ->            { where("updated_on > ?", 8.weeks.ago) }

    scope :disability,        ->            { where(disability: true) }
    scope :indigenous,        ->            { where(indigenous: true) }
    scope :not_for_profit,    ->            { where(not_for_profit: true) }
    scope :regional,          ->            { where(regional: true) }
    scope :sme,               ->            { where(sme: true) }
    scope :start_up,          ->            { where(start_up: true) }

    enumerize :abn_exempt, in: [
      'non-exempt', 'non-australian', 'insufficient-turnover', 'other'
    ]
    enumerize :number_of_employees, in: [
      'sole', '2to4', '5to19', '20to49', '50to99', '100to199', '200plus',
    ]
    enumerize :australia_employees, in: [
      'zero', 'sole', '2to4', '5to19', '20to49', '50to99', '100to199', '200plus',
    ]
    enumerize :nsw_employees, in: [
      'zero', 'sole', '2to4', '5to19', '20to49', '50to99', '100to199', '200plus',
    ]
    enumerize :corporate_structure, in: ['standalone', 'subsidiary', 'overseas']
    enumerize :business_structure, in: ['sole-trader', 'company', 'partnership', 'trust']
    enumerize :annual_turnover, in: ['under-3m', '3m-10m', '10m-25m', '25m-50m', '50m-100m', 'over-100m']

    SERVICE_LEVELS = {
      'community-and-social-services' => {
        'bushfire-affected-communities-rebuild' => [
#         'agency-government-or-private-buyer',
#         'building-works-associated-trades-and-materials',
#         'health',
#         'hospitality',
#         'native-wildlife',
#         'other-bushfire-services',
        ],
      },
      'construction' => {
        'construction-under-1-million' => [
          'construction-works',
          'building-services',
          'trades',
        ],
        'heritage-conservation-consultants' => [
          'consultant',
          'structural-engineer',
          'landscape-specialist',
          'interiors',
          'archaeologist-excavation-director',
          'research-and-support-archaeologist',
          'heritage-interpretation',
          'historian',
          'materials-conservators',
          'materials-testing',
          'other-heritage-consultants',
        ],
        'land-housing-residential' => [
          'new-construction-projects',
          'building-upgrade-projects',
        ],
      },
      'educational-supplies' => {},
      'engineering-research-and-technology-services' => {
        'remote-sensing-services-and-equipment' => [
          'aircraft-services',
          'data-and-processing',
          'remote-sensing-hardware-and-software',
          'design',
        ],
        'technical-services ' => [
          'survey',
          'geotechnical-and-pavement',
          'environment',
          'estimating',
          'construction-services',
          'health-and-safety-in-design',
        ],
      },
      'fleet-management' => {
        'motor-vehicles' => [
#         'buses',
#         'heavy-commercial',
#         'pu-cc-4x2',
#         'cc-cc-4x4',
#         'passenger-large',
#         'passenger-light',
#         'passenger-medium',
#         'passenger-small',
#         'passenger-upper-large',
#         'people-mover',
#         'suv-large',
#         'suv-medium',
#         'suv-small',
#         'vans/cc',
        ]
      },
      'food' => {},
      'healthcare-services' => {
#       'emergency-supplies' => [],
#       'employment-related-medical-services' => [],
      },
      'recruitment-and-human-resources' => {
        'recruitment-services' => [],
        'contingent-workforce' => [
          'administration',
          'finance',
          'specialist',
          'industrial',
          'industrial-act',
          'technical',
          'ict-network-and-equipment',
          'ict-management',
          'ict-applications',
          'transport',
          'rail-specific-project-management',
          'rail-specific-engineering',
          'rail-specific-design-and-architecture',
          'rail-specific-infrastructure',
          'safety-legal',
          'education',
          'other-contingent-workforce',
          'nsw-state-emergency-services',
          'home-care-service-of-nsw',
        ],
        'talent-acquisition' => [
          'design-and-delivery-of-assessments',
          'talent-search',
          'psychometric-tools',
          'recruitment-technologies',
        ],
      },
      'information-communications-technology' => {
        'advisory-and-consulting' => [
#         'strategy-planning-policy-and-risk',
#         'audits-compliance-and-assurance',
#         'project-and-change-management',
#         'training-and-development',
        ],
        'cloud-products-and-support' => [
#         'cloud-applications-and-software',
#         'cloud-hosting-and-infrastructure',
#         'cloud-support',
        ],
        'end-user-computing-and-peripherals' => [
#         'desktops-workstations-and-thin-clients',
#         'laptops-tablets-and-hybrids',
#         'printers-screens-and-monitors',
#         'peripherals-accessories-and-other-end-user-computing-products',
#         'end-user-computing-support',
        ],
        'infrastructure-and-network' => [
#         'modems-and-routers',
#         'switches-servers-and-storage',
#         'racks-and-cables',
#         'other-networking-products',
#         'network-and-security-support',
        ],
        'managed-and-outsourced-services' => [
#         'service-desk',
#         'contact-centre',
#         'network-and-security-operations',
#         'data-centre-operations',
#         'security-operations',
        ],
        'software-design-and-development' => [
#         'digital-design',
#         'software-development-integration-and-implementation',
#         'mobile-applications-development',
#         'system-and-software-testing-uat-and-assurance',
#         'system-architecture',
        ],
        'software-licensing-and-maintenance' => [
#         'systems-and-operating-software',
#         'enterprise-and-platforms-software',
#         'productivity-software',
#         'databases-and-middleware',
#         'mobile-applications',
#         'specialised-software',
#         'network-and-security-software',
        ],
        'telecommunications' => [
#         'fixed-data-and-internet',
#         'fixed-voice',
#         'mobiles',
#         'radio',
#         'telco-professional-services',
        ],
      },
      'marketing-and-advertising' => {
        'editorial-copy-writing' => [],
        'design-graphic-fine-art' => [],
        'advertising-and-digital-communications' => [
          'market-research',
          'advertisement-strategy',
          'marketing-and-campaign-services',
          'public-relations',
          'social-media',
          'indigenous-communications-and-engagement',
          'clad-communications-and-engagement',
          'visual-communications',
          'written-communications',
          'digital-communications',
          'production',
        ],
      },
      'office-supplies-and-services' => {
        'office-and-workplace' => [],
#        'office-furniture' => [],
#        'office-stationery-supply' => [],
      },
      'professional-services' => {
        'performance-and-management-services' => [
          'government-and-business-strategy',
          'management-business-processes',
          'project-management',
          'change-management',
          'financial-services',
          'audit-quality-assurance-and-risk',
          'taxation',
          'human-resources',
          'procurement-and-supply-chain',
          'marketing-and-customer',
          'actuarial-services',
          'transaction-services',
          'specialised-services',
          'infrastructure',
        ],
        'government-architect' => [
#         'strategy-architect',
#         'design-excellence',
        ],
        'consultants-in-construction' => [
#         'engineering',
#         'architectural',
#         'assessment',
#         'planning',
#         'management',
        ],
        'statutory-appointments' => [
#         'conveyancers-licensing-manager',
#         'conveyancers-licensing-receiver',
#         'property-stock-and-business-accounts-examiner',
#         'property-stock-and-business-manager',
#         'property-stock-and-business-receiver',
        ],
        'subsidence-advisory-nsw-independent-assessment' => [
#         'building-inspector-and-estimator',
#         'civil-engineering',
#         'environmental-studies',
#         'geotechnical-engineering',
#         'property-valuer',
#         'quantity-surveying',
#         'rail-engineers',
#         'structural-engineering',
#         'surveyor',
#         'utility-and-asset-locating-consultant',
        ],
        'land-asset-valuation' => [
#         'area',
#         'land-value-advisory-and-objection',
#         'compensation-recommendation-of-determination',
#         'real-property-and-asset-valuations',
#         'acquisition-valuation-services',
        ],
        'digital-engineering-service' => [
#         'digital-engineering-advisory',
#         'digital-business-processes',
#         'technology',
#         'data-management',
#         'modelling',
#         'visualisation',
#         'education-and-training',
#         'additional-digital-services',
        ],
      },
      'property-management-and-maintenance' => {
        'property-management' => [],
        'property-maintenance' => [],
        'property-utilities' => [],
      },
      'travel' => {
        'travel-and-transport' => [],
#       'domestic-travel-accommodation' => [],
      },
#      'utilities' => {
#        'energy-efficiency-services' => [],
#        'rolling-stock-engineering-and-specialist-services' => [],
#        'solar-ppa' => [],
#      },
    }

    before_save :remove_invalid_services

    def remove_invalid_services
      self.services = (self.services || []) & self.class.all_services
    end

    def self.service_levels
      SellerVersion::SERVICE_LEVELS
    end

    def self.flat_sub_categories
      h = self.service_levels.map{|k,v| [k, v.keys]}.to_h
      g = self.service_levels.values.reduce(h){|v, h| h.merge(v)}
      f = g.map{|k,v| [k, v.map{|s| {key: s, label: 'friendly'}}]}
      f.select{|k,v| v.present?}.to_h
    end

    def self.super_category service
      service_levels.each do |k, v|
        return k if v.keys.include? service
        v.each do |k, v|
          return k if v.include? service
        end
      end
      nil
    end

    def self.all_services
      level_1_services + level_2_services + level_3_services
    end

    def self.level_1_and_2_services
      self.level_1_services + level_2_services
    end

    def self.level_1_services
      SERVICE_LEVELS.keys
    end

    def self.level_2_services
      SERVICE_LEVELS.values.map(&:keys).flatten
    end

    def self.level_3_services
      SERVICE_LEVELS.values.map(&:values).flatten
    end

    def level_1_services
      (services || []).to_a & self.class.level_1_services
    end

    def level_2_services
      (services || []).to_a & self.class.level_2_services
    end

    def level_3_services
      (services || []).to_a & self.class.level_3_services
    end

    def government_experience
      [
        :no_experience,
        :local_government_experience,
        :state_government_experience,
        :federal_government_experience,
        :international_government_experience,
      ].map { |key| [key, self.send(key)] }.to_h
    end

    def normalise_abn
      self.abn = ABN.new(abn).to_s if ABN.valid?(abn)
    end

    def is_latest?
      next_version.nil?
    end

    def tags
      @tags ||= SellerService::SellerFieldStatus.where(seller_id: seller_id).to_a
    end

    def self.with_term(t)
      if t.present?
        search_by_term(t)
      else
        all
      end
    end

    def self.with_category(category)
      return all if category.blank?
      where(":category = ANY(services)", category: category)
    end

    def self.with_services(services)
      return all if services.blank?
      where("services && ARRAY[:services]", services: services)
    end

    def self.with_identifiers(identifiers)
      return all if identifiers.blank?
      scope_sqls = {
        "start_up" => "start_up = true",
        "disability" => "disability = true",
        "indigenous" => "indigenous = true",
        "not_for_profit" => "not_for_profit = true",
        "regional" => "regional = true",
        "sme" => "sme = true",
        "govdc" => "govdc = true"
      }
      sql = identifiers.map{|i| scope_sqls[i]}.join(' or ')
      where("(#{sql})")
    end 

    def self.with_locations(locations)
      return all if locations.blank?
      scope_sqls = {
        "nsw" => "addresses::json#>>'{0,state}' = 'nsw'",
        "au" => "addresses::json#>>'{0,country}' = 'AU'",
        "nz" => "addresses::json#>>'{0,country}' = 'NZ'",
        "int" => "addresses::json#>>'{0,country}' not in ('AU', 'NZ')",
      }
      sql = locations.map{|i| scope_sqls[i]}.join(' or ')
      where("(#{sql})")
    end 

    def self.with_company_size(sizes)
      return all if sizes.blank?
      scope_sqls = {
        "1to19" => "number_of_employees in ('sole', '2to4', '5to19')",
        "20to49" => "number_of_employees = '20to49'",
        "50to99" => "number_of_employees = '50to99'",
        "200plus" => "number_of_employees = '200plus'",
      }
      sql = sizes.map{|i| scope_sqls[i]}.join(' or ')
      where("(#{sql})")
    end 

    def self.with_profile(fields)
      return all if fields.blank?
      scope_sqls = {
        "case-studies" => "json_array_length(seller_profile_versions.case_studies) > 0",
        "references" => "json_array_length(seller_profile_versions.references) > 0",
        "government-projects" => "json_array_length(seller_profile_versions.government_credentials) > 0",
      }
      sql = fields.map{|i| scope_sqls[i]}.join(' or ')
      eager_load(:last_profile_version).where("(#{sql})")
    end 
  end
end
