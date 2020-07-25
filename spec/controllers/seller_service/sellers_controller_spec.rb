require 'rails_helper'

RSpec.describe SellerService::SellersController, type: :controller do
  routes {SellerService::Engine.routes }

  let(:sv)      { create(:approved_seller_version) }
  let(:seller)  { sv.seller }
  let(:sv2)     { create(:created_seller_version_with_profile) }
  let(:seller2) { create(:inactive_seller, versions: [sv2]) }
  let(:user)    { double("User", id: 6, email: '', seller_id: seller.id, roles: ['seller'], is_admin?: false, is_seller?: true) }
  let(:user2)   { double("User", id: 5, email: '', seller_id: seller2.id, roles: ['seller'], is_admin?: false, is_seller?: true) }
  let(:admin)   { double("User", id: 1, email: 'admin@admin.com', roles: ['admin'], is_admin?: true, is_seller?: false, seller_id: nil) }

  describe 'testing the controller functions' do

    xit 'should create seller and seller version' do
      user2 = double("User", id: 2, email: '', seller_id: nil, roles: ['seller'], token: "test", is_admin?: false, is_seller?: true, :update_attributes! => true)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user2)
      allow(SharedResources::RemoteUser).to receive(:update_seller)
      expect{post :create}.to change{SellerService::Seller.count}.by(1)
      expect(SellerService::Seller.last.versions.count).to eq(1)
    end

    xit 'should get seller instead of creating if one exists for the user' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      expect{post :create}.to change{SellerService::Seller.count}.by(0)
    end

    xit 'should get index' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      get :index
      assert_response :success
    end

    xit 'should get index for telco' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      get :index, params: {telco: true}
      assert_response :success
    end

    xit 'should get index based on current user' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      get :index, params: {current: true}
      assert_response :success
    end

    xit 'should get show' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      get :show, params: {id: user.seller_id}
      assert_response :success
    end

    xit 'should be able to run through each operation' do
      class_double("SlackPostJob", :perform_later => true).as_stubbed_const
      message = instance_double(ActionMailer::MessageDelivery)
      class_double("SellerApplicationMailer", :application_changes_requested_email => message, :application_approved_email => message).as_stubbed_const
      allow(SellerApplicationMailer).to receive(:with).with(an_instance_of(Hash)).and_return(SellerApplicationMailer)
      allow(message).to receive(:deliver_later)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user2)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:authenticate_service).and_return(true)
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      allow(SharedResources::RemoteUser).to receive(:get_by_email).and_return(nil)
      allow(SharedResources::RemoteDocument).to receive(:can_attach?).and_return(true)
      
      s = seller2
      expect(s.has_draft?).to be_truthy

      post :submit, params: {id: s.id + 1}
      expect(response.success?).to be_falsey

      post :submit, params: {id: s.id}
      assert_response :success

      post :withdraw, params: {id: s.id}
      assert_response :success

      post :submit, params: {id: s.id}
      assert_response :success

      post :cancel, params: {id: s.id}
      expect(response.success?).to be_falsey      
      
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(admin) 
      
      post :assign, :params => {:id => s.id}, :body => {:assignee => {id: admin.id, email: admin.email}}.to_json, as: :json
      assert_response :success

      post :approve, :params => {:id => s.id}, :body => {:field_statuses => {:name => "approve"}}.to_json, as: :json
      assert_response :success

      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user2) 
      post :deactivate, params: {id: s.id}
      assert_response :success
      s.reload
      expect(s.has_deactivated?).to be_truthy

      post :activate, params: {id: s.id}
      assert_response :success

      post :start_amendment, params: {id: s.id}
      assert_response :success

      post :submit, params: {id: s.id}
      assert_response :success
      s.reload
      expect(s.status).to eq(:amendment_pending)

      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(admin) 

      s.reload
      s.last_version.update_attributes(assigned_to_id: admin.id)
      post :decline, :params => {:id => s.id}, :body => {:field_statuses => {}}.to_json, as: :json
      s.reload
      expect(s.has_declined?).to be_truthy

      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user2) 

      post :revise, params: {id: s.id}
      assert_response :success

      post :destroy, params: {id: s.id}
      assert_response :success
    end
  end
end
