module SellerService::Account
  class BusinessIdentifierForm < SellerService::Account::AuditableForm
    field :start_up
    field :sme
    field :not_for_profit
    field :australian_owned
    field :disability
    field :indigenous_optout

    field :addresses, usage: :back_end
    field :establishment_date, usage: :back_end
    field :number_of_employees, usage: :read_only
    field :abn, usage: :back_end

    field :can_be_startup, usage: :front_end
    field :overseas, usage: :front_end

    field :indigenous_verified, usage: :front_end

    def establishment_date_in_range
      establishment_date.present? && establishment_date > 5.years.ago
    end

    def indigenous_certified
      cert = SellerService::Certification.find_by(cert_display: 'Aboriginal')
      if cert.present?
        SellerService::SupplierCertificate.find_by(supplier_abn: abn, certification_id: cert.id).present?
      else
        cert.present?
      end
    end

    def after_load
      self.can_be_startup = establishment_date_in_range
      self.overseas = addresses.blank? || !addresses.first['country'].in?(['AU','NZ'])
      self.start_up = false unless establishment_date_in_range
      self.sme = false if number_of_employees == '200plus' || overseas
      self.indigenous_verified = indigenous_certified
    end

    def before_save
      self.overseas = addresses.blank? || !addresses.first['country'].in?(['AU','NZ'])
      self.sme = false if number_of_employees == '200plus' || overseas
      self.start_up = false unless establishment_date_in_range
    end
  end
end
