require 'rails_helper'

RSpec.describe SellerService::Seller do
  let(:version) {create(:approved_seller_version)}
  let(:seller)  {create(:active_seller, versions: [version])}

  let(:user)    { double("User", id: 1, seller_id: seller.id, roles: ['seller'], is_admin?: false, is_seller?: true, email: "test@test.com") }
  let(:user_2)  { double("User", id: 2, seller_id: seller.id, roles: ['seller', :admin], is_admin?: true, is_seller?: true, email: "test@test.com") }
  let(:admin)  { double("User", id: 3, seller_id: seller.id, roles: ['admin'], is_admin?: true, is_seller?: false, email: "admin@admin.com") }

  describe '#last_edited_at' do
    it 'returns the created at time for latest seller version' do
      version.reload
      expect(seller.last_edited_at).to eq(version.created_at)
    end
  end
  
  describe '#run_action' do
    xit 'goes through the whole journey' do
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      allow(SharedResources::RemoteUser).to receive(:get_by_email).and_return(nil)

      class_double("SlackPostJob", :perform_later => true).as_stubbed_const

      message = instance_double(ActionMailer::MessageDelivery)
      class_double("SellerApplicationMailer", :application_changes_requested_email => message, :application_approved_email => message).as_stubbed_const
      allow(SellerApplicationMailer).to receive(:with).with(an_instance_of(Hash)).and_return(SellerApplicationMailer)
      allow(message).to receive(:deliver_later)

      expect(seller.versions.size).to eq(1)

      seller.run_action(:start_amendment, user: user)
      expect(seller.status).to eq(:amendment_draft)

      seller.run_action(:cancel, user: user)
      expect(seller.status).to eq(:live)

      seller.run_action(:start_amendment, user: user)
      expect(seller.status).to eq(:amendment_draft)
      expect(seller.can_be_withdrawn?).to eq(false)

      seller.run_action(:submit, user: user)
      expect(seller.status).to eq(:amendment_pending)

      seller.run_action(:withdraw, user: user)
      expect(seller.status).to eq(:amendment_draft)

      seller.run_action(:submit, user: user)
      expect(seller.status).to eq(:amendment_pending)

      seller.run_action(:assign, user: admin, props: { assignee: {id: admin.id, email: admin.email} })
      seller.run_action(:decline, user: user, props: {field_statuses: {}})
      expect(seller.status).to eq(:amendment_changes_requested)

      seller.run_action(:revise, user: user)
      expect(seller.status).to eq(:amendment_draft)

      seller.run_action(:submit, user: user)
      expect(seller.status).to eq(:amendment_pending)

      seller.run_action(:assign, user: user, props: { assignee: {id: user.id, email: user.email} })
      expect(seller.status).to eq(:amendment_pending)

      seller.run_action(:approve, user: user, props: {field_statuses: {}})
      expect(seller.status).to eq(:live)

      seller.run_action(:deactivate, user: user)
      expect(seller.status).to eq(:deactivated)

      seller.run_action(:activate, user: user)
      expect(seller.status).to eq(:live)
    end
  end

  describe '#events' do
    it 'gets events associated with seller' do
      allow_any_instance_of(SellerService::Seller).to receive(:events).and_return(:seller_events)
      expect(seller.events).to eq(:seller_events)
    end
  end

  describe '#status and #valid_actions' do
    let(:version_2) {create(:returned_to_applicant_seller_version)}
    let(:seller_2)  {create(:inactive_seller, versions: [version_2])}
    let(:archived) {create(:archived_seller_version)}
    let(:seller_3) {create(:active_seller, versions: [archived])}
    let(:user_3)    { double("User", id: 4, seller_id: seller_2.id, roles: ['seller'], is_admin?: false, is_seller?: true, email: "test@test.com") }

    it 'has a changes requested status on a decline version state' do
      expect(seller_2.status).to eq(:changes_requested)
    end

    it 'can only revise when changes requested status' do
      expect(seller_2.valid_actions).to eq([:revise])
    end

    it 'cant take any actions when the last version is archived' do
      expect(seller_3.valid_actions).to eq([])
    end

    it 'cannot cancel before going live' do
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      seller_2.run_action(:revise, user: user_3)
      expect{seller_2.run_action(:cancel, user: user_3)}.to raise_error{"Invalid Action Cancel in status Draft"}
    end

    it 'returns the previous decision on a field' do
      seller.seller_field_statuses.create(field: 'name', status: 'reject', value: "\"test name\"")
      expect(seller.previous_decision('name')).to eq('reject')
    end
  end   

  describe '#decline' do
    let(:version_2) {create(:ready_for_review_seller_version)}
    let(:seller_2)  {create(:inactive_seller, versions: [version_2])}

    it 'creates a new version with state declined when not live' do
      message = instance_double(ActionMailer::MessageDelivery)
      class_double("SellerApplicationMailer", :application_changes_requested_email => message, :application_approved_email => message).as_stubbed_const
      allow(SellerApplicationMailer).to receive(:with).with(an_instance_of(Hash)).and_return(SellerApplicationMailer)
      allow(message).to receive(:deliver_later)
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      seller_2.run_action(:decline, user: admin, props: {field_statuses: {name: 'reject', abn: 'reject'}})
      seller_2.reload
      expect(seller_2.last_version.state).to eq("declined")
    end
  end

  describe '#form status' do
    let(:version_2) {create(:ready_for_review_seller_version)}
    let(:seller_2)  {create(:inactive_seller, versions: [version_2])}


    before(:each) do
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      class_double("SlackPostJob", :perform_later => true).as_stubbed_const
    end

    xit 'returns incomplete if not accepted before and contract is started but not finished' do
      version_2.update_attributes(govdc: nil)
      expect(seller_2.form_status(:services)).to be(:incomplete)
    end

    xit 'places under review when the user is asked to change a field' do
      seller.seller_field_statuses.create(field: 'name', status: 'reject', value: "\"test\"")
      seller.seller_field_statuses.create(field: 'abn', status: 'reject', value: "\"81 913 830 179 \"")
      expect(seller.form_status(:business_details)).to be(:please_review)
      expect(seller.no_reject?).to be_falsey
    end

    xit 'changes to under review when a user goes back to draft state' do
      seller.seller_field_statuses.create(field: 'contact_name', status: 'reviewed', value: "\"test\"")
      seller.seller_field_statuses.create(field: 'abn', status: 'reviewed', value: "\"81 913 830 179\"")
      seller.run_action(:start_amendment, user: user)
      seller.run_action(:submit, user: user)
      expect(seller.form_status(:business_details)).to be(:under_review)
    end

    xit 'changes to update when the user changes the value' do
      seller.seller_field_statuses.create(field: 'contact_name', status: 'reviewed', value: "\"test\"")
      seller.seller_field_statuses.create(field: 'abn', status: 'reviewed', value: "\"81 913 830 179\"")
      expect(seller.form_status(:business_details)).to be(:updated)
    end

    xit 'returns deleted when the seller has been deleted' do
      seller.destroy
      expect(seller.form_status(:business_details)).to be(:deleted)
    end
  end

  describe '#field_statuses' do
    before(:each) do
      class_double("SlackPostJob", :perform_later => true).as_stubbed_const
      message = instance_double(ActionMailer::MessageDelivery)
      class_double("SellerApplicationMailer", :application_changes_requested_email => message, :application_approved_email => message).as_stubbed_const
      allow(SellerApplicationMailer).to receive(:with).with(an_instance_of(Hash)).and_return(SellerApplicationMailer)
      allow(message).to receive(:deliver_later)
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(user)
    end
    xit 'updates all the relevant fields on submission' do      
      seller.seller_field_statuses.create(field: 'name', status: 'reviewed', value: "\"test\"")
      seller.seller_field_statuses.create(field: 'abn', status: 'reviewed', value: "\"81 913 830 179\"")
      seller.run_action(:start_amendment, user: user)
      seller.run_action(:submit, user: user)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(admin)
      seller.run_action(:assign, user: admin, props: { assignee: {id: admin.id, email: admin.email} })
      seller.run_action(:approve, user: admin, props: {field_statuses: {name: 'accept', abn: 'accept'}})
      expect(seller.seller_field_statuses.where(field: 'name').first.status).to eq('accept')
      expect(seller.seller_field_statuses.where(field: 'abn').first.status).to eq('accept')
      expect(seller.form_status(:business_details)).to eq(:accepted)
      expect(seller.no_reject?).to be_truthy
    end

    xit 'marks rejected fields clearly for a rejected application' do
      allow(SharedResources::RemoteUser).to receive(:get_by_email).and_return(nil)
      seller.seller_field_statuses.create(field: 'name', status: 'accept', value: "\"test\"")
      seller.seller_field_statuses.create(field: 'abn', status: 'accept', value: "\"81 913 830 179\"")
      seller.run_action(:start_amendment, user: user)
      seller.last_version.update_attributes(name:'new_name')
      seller.last_version.update_attributes(abn:'84 104 377 806 ')
      seller.run_action(:submit, user: user)
      allow_any_instance_of(SellerService::ApplicationController).to receive(:session_user).and_return(admin)
      seller.run_action(:assign, user: admin, props: { assignee: {id: admin.id, email: admin.email} })
      seller.run_action(:decline, user: admin, props: {field_statuses: {name: 'reject', abn: 'reject'}})
      expect(seller.seller_field_statuses.where(field: 'name').first.status).to eq('reject')
      expect(seller.seller_field_statuses.where(field: 'abn').first.status).to eq('reject')
    end
  end
end
