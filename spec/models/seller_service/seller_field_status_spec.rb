require 'rails_helper'

RSpec.describe SellerService::SellerFieldStatus, type: :model do
  let(:sv)      { create(:ready_for_review_seller_version) }
  let(:seller)  { create(:inactive_seller, versions: [sv]) }
  let(:user)    { double("User", roles: ['admin', 'seller'], id: 1, seller_id: seller.id, is_admin?: true, email: "test@test.com")}
  
  let(:sfs)     { create(:seller_field_status, seller: seller)}

  describe "allows for field statuses to be saved and updated" do
    context "in the save field statuses method" do
      it 'updates the status of the fields' do
        seller.save_field_statuses({"name" => "approved", "abn" => "declined"})
        
        expect(seller.seller_field_statuses.count).to eq(2)
        expect(seller.seller_field_statuses[0].status).to eq("approved")
        expect(seller.seller_field_statuses[1].status).to eq("declined")
      end
    end

    context "in the update field statuses method" do
      let(:approved_sv) {create(:approved_seller_version)}
      let(:active_seller) { create(:active_seller, versions: [approved_sv]) }
      let(:user2)    { double("User", roles: ['admin', 'seller'], id: 1, seller_id: active_seller.id, is_admin?: true, email: "test@test.com")}

      it 'raises an exception if there is no draft' do
        expect{active_seller.update_field_statuses("test")}.to raise_error(SharedModules::AlertError)
      end

      it 'updates the fields correctly' do
        allow(SharedResources::ApplicationResource).to receive(:generate_token)
        allow(SharedResources::RemoteEvent).to receive(:create_event)
        active_seller.run_action(:start_amendment, user: user2)
        active_seller.seller_field_statuses.create(field: 'services', status: 'reject', value: "")
        active_seller.last_version.update_attributes(services: ['cloud-services'])
        active_seller.update_field_statuses(:product_category)
        expect(active_seller.seller_field_statuses.where(field: 'services').first.status).to eq('reviewed')
      end
    end
  end
end
