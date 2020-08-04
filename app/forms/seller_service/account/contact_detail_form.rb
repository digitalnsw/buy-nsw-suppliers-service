module SellerService::Account
  class ContactDetailForm < SellerService::Account::AuditableForm
    field :contact_first_name
    field :contact_last_name
    field :contact_email
    field :contact_phone
    field :contact_position

    field :representative_first_name
    field :representative_last_name
    field :representative_email
    field :representative_phone
    field :representative_position

    field :same_as_above, usage: :front_end

    validates :contact_first_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_last_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :contact_phone, format: { with: /\A(\+)?[0-9 ()\-]{3,20}\z/ }
    validates :contact_position, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :representative_first_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :representative_last_name, format: { with: /\A[A-Za-z .'\-]+\z/ }
    validates :representative_email, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :representative_phone, format: { with: /\A(\+)?[0-9 ()\-]{3,20}\z/ }
    validates :representative_position, format: { with: /\A[A-Za-z .'\-]+\z/ }

    def after_load
      self.same_as_above = false
    end

    def before_save
      self.representative_email.downcase! if representative_email.present?
      self.contact_email.downcase! if contact_email.present?
      if same_as_above.present?
        self.representative_first_name = self.contact_first_name
        self.representative_last_name = self.contact_last_name
        self.representative_email = self.contact_email
        self.representative_phone = self.contact_phone
      end
    end
  end
end
