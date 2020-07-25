module SellerService::Profile
  class CapabilityAndExpertyForm < SellerService::BaseForm
    field :methodologies
    field :knowledge_base
    field :quality_control
    field :security
    validates :methodologies, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
    validates :knowledge_base, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
    validates :quality_control, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
    validates :security, format: { with: /\A[A-Za-z0-9 .,'":;+~*\-_|()@#$%&\/\s]{0,1000}\z/ }
  end
end
