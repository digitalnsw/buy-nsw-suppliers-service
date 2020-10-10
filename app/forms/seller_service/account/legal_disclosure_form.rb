module SellerService::Account
  class LegalDisclosureForm < SellerService::Account::AuditableForm
    field :receivership
    field :receivership_details

    field :bankruptcy
    field :bankruptcy_details

    field :investigations
    field :investigations_details

    field :legal_proceedings
    field :legal_proceedings_details

    def after_load
      self.receivership_details ||= ""
      self.bankruptcy_details ||= ""
      self.investigations_details ||= ""
      self.legal_proceedings_details ||= ""
    end

    def before_save
      self.receivership_details = "" if receivership.blank? || receivership == 'false'
      self.bankruptcy_details = "" if bankruptcy.blank? || bankruptcy == 'false'
      self.investigations_details = "" if investigations.blank? || investigations == 'false'
      self.legal_proceedings_details = "" if legal_proceedings.blank? || legal_proceedings == 'false'
    end

    validates :receivership, inclusion: { in: [false, true, 'false', 'true'] }
    validates :receivership_details, presence: true, if: -> { receivership.to_s == 'true' }
    validates :receivership_details, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }

    validates :bankruptcy, inclusion: { in: [false, true, 'false', 'true'] }
    validates :bankruptcy_details, presence: true, if: -> { bankruptcy.to_s == 'true' }
    validates :bankruptcy_details, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }

    validates :investigations, inclusion: { in: [false, true, 'false', 'true'] }
    validates :investigations_details, presence: true, if: -> { investigations.to_s == 'true' }
    validates :investigations_details, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }

    validates :legal_proceedings, inclusion: { in: [false, true, 'false', 'true'] }
    validates :legal_proceedings_details, presence: true, if: -> { legal_proceedings.to_s == 'true' }
    validates :legal_proceedings_details, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
  end
end
