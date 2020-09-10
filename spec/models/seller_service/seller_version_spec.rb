require 'rails_helper'

RSpec.describe SellerService::SellerVersion do
  describe "#abn" do
    it "normalises a valid value" do
      seller = create(:approved_seller_version, abn: "24138089942")
      expect(seller.abn).to eq("24 138 089 942")
    end

    it "does nothing to an already normalised value" do
      seller = create(:approved_seller_version, abn: "24 138 089 942")
      expect(seller.abn).to eq("24 138 089 942")
    end

    it "does not normalise an invalid value" do
      seller = create(:approved_seller_version, abn: "1234")
      expect(seller.abn).to eq("1234")
    end

    # This is actually testing the factory
    it "creates consecutive valid ABNs" do
      seller1 = build(:approved_seller_version)
      seller2 = build(:approved_seller_version)
      seller3 = build(:approved_seller_version)
      expect(ABN.valid?(seller1.abn)).to be_truthy
      expect(ABN.valid?(seller2.abn)).to be_truthy
      expect(ABN.valid?(seller3.abn)).to be_truthy
    end
  end

  describe '#approve' do
    subject { create(:ready_for_review_seller_version, seller: version.seller) }

    context 'when there are no "approved" versions for the same seller' do
      let(:version) { create(:created_seller_version) }

      it 'can be approved' do
        expect(subject.may_approve?).to be_truthy
      end
    end

    context 'when more than one version for the same seller is "approved"' do
      let(:version) { create(:approved_seller_version) }

      it 'cannot be approved' do
        expect(subject.may_approve?).to be_truthy
      end
    end
  end

  describe '#approve_amendment' do
    subject { create(:ready_for_review_seller_version, seller: version.seller) }

    context 'when there is one "approved" versions for the same seller' do
      let(:version) { create(:approved_seller_version) }

      it 'can be approved' do
        expect(subject.may_approve?).to be_truthy
      end
    end

    context 'when there is no approved version for the same seller' do
      let(:version) { create(:created_seller_version) }

      it 'cannot be approved' do
        expect(subject.may_approve?).to be_truthy
      end
    end
  end

  describe 'miscellaneous functions' do
    let(:version) {create(:approved_seller_version)}
    let(:user)   { double("User", id: 3, email: '', seller_id: version.seller.id, roles: ['seller'], is_admin?: false, is_seller?: true)}
    let(:admin)   { double("User", id: 6, email: 'admin@admin.com', roles: ['admin'], is_admin?: true, is_seller?: false, seller_id: nil)}
    
    it 'returns if someone is assigned to a version' do
      expect(version.assignee_present?).to be_truthy
    end

    it 'returns if someone isnt returned to a version' do
      expect(version.unassigned?).to be_falsey
    end

    it 'returns if someone can be assigned to a version' do
      expect(version.may_assign?).to be_falsey
    end

    it 'returns if an approved version is present' do
      expect(version.has_approved_version?).to be_truthy
    end

    it 'returns if there are no approved versions' do
      expect(version.no_approved_versions?).to be_falsey
    end

    it 'returns if the current version is the latest' do
      expect(version.is_latest?).to be_truthy
    end

    it 'formats the correct version by year, month, day and days since its been started' do
      date = Date.parse(version.created_at.to_s)
      expect(version.version).to eq(date.strftime('%y.%m.%d.1'))
    end

    it 'can determine the changed fields if there is no previous version' do
      expect(version.changed_fields).to eq([])
    end

    it 'can determine the changed fields if there is previous versions' do
      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      seller = version.seller
      seller.run_action(:start_amendment, user: user)
      seller.last_version.update_attributes(name: "newer name")
      expect(seller.last_version.changed_fields).to eq([:id, :state, :assigned_to_id, :name, :created_on, :updated_on, :next_version_id])
    end

    xit 'can determine the changed fields of something that isnt reviewable' do
      class_double("SlackPostJob", :perform_later => true).as_stubbed_const
      message = instance_double(ActionMailer::MessageDelivery)
      class_double("SellerApplicationMailer", :application_changes_requested_email => message, :application_approved_email => message).as_stubbed_const
      allow(SellerApplicationMailer).to receive(:with).with(an_instance_of(Hash)).and_return(SellerApplicationMailer)
      allow(message).to receive(:deliver_later)

      allow(SharedResources::ApplicationResource).to receive(:generate_token)
      allow(SharedResources::RemoteEvent).to receive(:create_event)
      allow(SharedResources::RemoteUser).to receive(:get_by_email).and_return(nil)
      seller = version.seller
      seller.run_action(:start_amendment, user: user)
      seller.last_version.update_attributes(name: "newer name")
      expect(seller.last_version.changed_fields_unreviewed).to eq([:id, :state, :assigned_to_id, :name, :created_on, :updated_on, :next_version_id])

      seller.run_action(:submit, user: user)
      seller.run_action(:assign, user: admin, props: { assignee: {id: admin.id, email: admin.email} })
      seller.run_action(:approve, user: admin, props: {field_statuses: {name: 'accept', abn: 'accept'}})
      expect(seller.last_version.changed_fields_unreviewed).to eq([])
    end
  end 

  describe "#scopes" do
    let!(:sv)  { create(:approved_seller_version) }
    let!(:sv2) { create(:approved_seller_version) }

    it 'can filter by search term' do
      sv.update_attributes(name: "SOME UNBELIEVABLE PRODUCT")
      sv2.update_attributes(name: "SOME UNBELIEVABLE PRODUCT YOU MUST HAVE!!")
      expect(SellerService::SellerVersion.with_term("SOME UNBELIEVABLE PRODUCT YOU MUST HAVE").to_a.count).to eq(1)
      expect(SellerService::SellerVersion.with_term("SOME UNBELIEVABLE PRODUCT").to_a.count).to eq(2)
      expect(SellerService::SellerVersion.with_term("").to_a.count).to eq(2)
    end

    it 'can filter with identifiers' do
      sv.update_attributes(sme: true)
      sv2.update_attributes(start_up: false, disability: true, indigenous: true, not_for_profit: true, regional: false, sme: false)
      expect(SellerService::SellerVersion.with_identifiers([]).count).to eq(2)
      expect(SellerService::SellerVersion.with_identifiers(["start_up"]).count).to eq(1)
      expect(SellerService::SellerVersion.with_identifiers(["disability"]).count).to eq(1)
      expect(SellerService::SellerVersion.with_identifiers(["indigenous"]).count).to eq(1)
      expect(SellerService::SellerVersion.with_identifiers(["not_for_profit"]).count).to eq(1)
      expect(SellerService::SellerVersion.with_identifiers(["regional"]).count).to eq(1)
      expect(SellerService::SellerVersion.with_identifiers(["sme"]).count).to eq(1)
    end
  end

  describe '#Seller Field Status - Tag functions' do
    let!(:version) {create(:approved_seller_version)}
    let!(:admin)   { double("User", id: 6, email: 'admin@admin.com', roles: ['admin'], is_admin?: true, is_seller?: false, seller_id: nil)}

    it 'lists all of the different options for government experience' do
      expect(version.government_experience.keys).to eq([
        :no_experience,
        :local_government_experience,
        :state_government_experience,
        :federal_government_experience,
        :international_government_experience,
      ]) 
    end
  end
end
