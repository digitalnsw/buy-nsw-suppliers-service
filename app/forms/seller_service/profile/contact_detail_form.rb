module SellerService::Profile
  class ContactDetailForm < SellerService::BaseForm
    field :website_url
    field :linkedin_url
    field :facebook_url
    field :twitter_url
    field :youtube_url
    field :instagram_url

    validates :website_url, format: { with: URI.regexp }, allow_blank: true
    validates :linkedin_url, format: { with: URI.regexp }, allow_blank: true
    validates :facebook_url, format: { with: URI.regexp }, allow_blank: true
    validates :youtube_url, format: { with: URI.regexp }, allow_blank: true
    validates :twitter_url, format: { with: URI.regexp }, allow_blank: true
    validates :instagram_url, format: { with: URI.regexp }, allow_blank: true
  end
end
