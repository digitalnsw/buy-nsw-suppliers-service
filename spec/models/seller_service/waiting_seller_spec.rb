require 'rails_helper'

RSpec.describe SellerService::WaitingSeller, type: :model do
  let(:waiting_seller) { create(:waiting_seller) }
  let(:invited_seller) { create(:invited_waiting_seller) }

  describe '#invitation_state' do
    it 'is "created" by default' do
      expect(SellerService::WaitingSeller.new.invitation_state).to eq('created')
    end
  end

  describe '#mark_as_invited' do
    it 'sets the invitation_state to "invited"' do
      waiting_seller.mark_as_invited

      expect(waiting_seller.invitation_state).to eq('invited')
    end
  end

  describe '#mark_as_joined' do
    it 'sets the invitation_state to "joined"' do
      invited_seller.mark_as_joined

      expect(invited_seller.invitation_state).to eq('joined')
    end
  end

  describe '#editable' do
    it 'checks if the user is editable' do
      expect(waiting_seller.editable?).to be_truthy
      expect(invited_seller.editable?).to be_falsey
    end
  end

  describe '#invitable' do
    it 'checks if the user is invitable' do
      expect(waiting_seller.invitable?).to be_truthy
      expect(invited_seller.invitable?).to be_falsey
    end
  end
end
