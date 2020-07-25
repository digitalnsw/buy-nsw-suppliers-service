module SellerService::Account
  class CompanyTypeAndSizeForm < SellerService::Account::AuditableForm
    field :number_of_employees
    field :australia_employees
    field :nsw_employees
    field :business_structure
    field :annual_turnover

    validates_presence_of :number_of_employees
    validates_presence_of :australia_employees
    validates_presence_of :nsw_employees
    validates_presence_of :business_structure
    validates_presence_of :annual_turnover
  end
end
