module SellerService::Profile
  class PromotionalVideoForm < SellerService::BaseForm
    YOUTUBE_ID_REGEX = /[0-9A-Za-z_-]{10}[048AEIMQUYcgkosw]/
    field :promotional_video
    # validates :promotional_video, format: { with: PromotionalVideoForm::YOUTUBE_ID_REGEX }

    def before_validate
      self.promotional_video = promotional_video.scan(PromotionalVideoForm::YOUTUBE_ID_REGEX).first
    end
  end
end
