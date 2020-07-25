require 'rails_helper'

RSpec.describe SellerService::PublicSellersController, type: :controller do
  routes {SellerService::Engine.routes }

  let!(:sv)     { create(:approved_seller_version)}
  let!(:seller) { sv.seller }

  describe 'testing the controller functions' do
    it 'should get index' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(nil)
      get :index
      assert_response :success
    end

    it 'should get show' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(nil)
      get :show, params: {id: seller.id}
      assert_response :success
    end

    it 'should get scoped sellers and get correct count' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(nil)
      get :index, params: {all: true}
      expect(JSON.parse(response.body)['publicSellers'].first['id']).to eq(sv.id)

      get :count
      expect(JSON.parse(response.body)['totalCount']).to eq(1)
    end
  end
end
