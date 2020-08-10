module SellerService::Profile
  class TeamMemberForm < SellerService::BaseForm
    field :team_members, type: :json

    validates :team_members, 'shared_modules/json': { schema:
      [
        {
          avatar_id: 'avatar?',
          first_name: 'name',
          last_name: 'name',
          role: 'limited?',
          email: 'email',
          speciality: 'text?',
        }
      ]
    }

    def after_load
      self.team_members ||= []
    end
  end
end
