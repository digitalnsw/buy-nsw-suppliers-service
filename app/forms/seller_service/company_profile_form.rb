module SellerService
  class CompanyProfileForm < SellerService::AuditableForm
    field :flagship_product
    field :summary
    field :website_url

    field :linkedin_url
    field :facebook_url
    field :youtube_url
    field :twitter_url
    field :instagram_url

    def optional?
      true
    end

    validates :flagship_product, format: { with: /\A[A-Za-z0-9 .'\-_()@&,\/]{0,100}\z/ }
    validates :summary, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
    validates :website_url, format: { with: URI.regexp }, allow_blank: true
    validates :linkedin_url, format: { with: URI.regexp }, allow_blank: true
    validates :facebook_url, format: { with: URI.regexp }, allow_blank: true
    validates :youtube_url, format: { with: URI.regexp }, allow_blank: true
    validates :twitter_url, format: { with: URI.regexp }, allow_blank: true
    validates :instagram_url, format: { with: URI.regexp }, allow_blank: true
  end
end
