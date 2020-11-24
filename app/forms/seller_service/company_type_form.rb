module SellerService
  class CompanyTypeForm < SellerService::AuditableForm
    field :number_of_employees
    field :australia_employees
    field :nsw_employees
    field :business_structure
    field :annual_turnover
    field :start_up
    field :sme
    field :not_for_profit
    field :australian_owned
    field :indigenous
    field :disability

    field :addresses, usage: :back_end
    field :establishment_date, usage: :back_end

    field :can_be_startup, usage: :front_end
    field :overseas, usage: :front_end

    def started?
      [
        :number_of_employees,
        :australia_employees,
        :nsw_employees,
        :business_structure,
        :annual_turnover,
        :start_up,
        :sme,
        :not_for_profit,
        :australian_owned,
        :indigenous,
        :disability,
      ].any? do |field|
        send(field).present?
      end
    end

    def establishment_date_in_range
      establishment_date.present? && establishment_date > 5.years.ago
    end

    def after_load
      self.can_be_startup = establishment_date_in_range 
      self.overseas = addresses.blank? || !addresses.first['country'].in?(['AU','NZ'])
      self.start_up = false unless establishment_date_in_range
      self.sme = false if number_of_employees == '200plus' || overseas
    end

    def before_save
      self.overseas = addresses.blank? || !addresses.first['country'].in?(['AU','NZ'])
      self.sme = false if number_of_employees == '200plus' || overseas
      self.start_up = false unless establishment_date_in_range
      align_employee_numbers
    end

    def align_employee_numbers
      index = {
        'zero' => 0,
        'sole' => 1,
        '2to4' => 2,
        '5to19' => 3,
        '20to49' => 4,
        '50to99' => 5,
        '100to199' => 6,
        '200plus' => 7,
      }
      all_index = index[number_of_employees]
      au_index = index[australia_employees]
      nsw_index = index[nsw_employees]

      self.australia_employees = number_of_employees if all_index && au_index && au_index > all_index
      self.nsw_employees = australia_employees if nsw_index && au_index && nsw_index > au_index
    end

    validates_presence_of :number_of_employees
    validates_presence_of :australia_employees
    validates_presence_of :nsw_employees
    validates_presence_of :business_structure
    validates_presence_of :annual_turnover
  end
end
