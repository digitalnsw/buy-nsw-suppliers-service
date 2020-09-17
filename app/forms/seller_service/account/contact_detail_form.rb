module SellerService::Account
  class ContactDetailForm < SellerService::Account::AuditableForm
    field :contact_first_name
    field :contact_last_name
    field :contact_email
    field :contact_phone
    field :contact_position

    validates :contact_first_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_last_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :contact_phone, format: { with: /\A(\+)?[0-9 ()\-]{3,20}\z/ }
    validates :contact_position, format: { with: /\A[A-Za-z .'\-]+\z/ }

    def before_save
      self.contact_email.downcase! if contact_email.present?
    end
  end
end
