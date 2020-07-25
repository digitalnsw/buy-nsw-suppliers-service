require 'rails_helper'

RSpec.describe SellerService::SellerSerializer do
  let!(:sv)           { create(:approved_seller_version) }
  let!(:sv_2)         { create(:approved_seller_version) }
  let!(:sv_3)         { create(:approved_seller_version) }
  let!(:seller)       { create(:active_seller, versions: [sv])}
  let!(:seller_2)     { create(:active_seller, versions: [sv_2]) }
  let!(:seller_3)     { create(:active_seller, versions: [sv_3]) }
  let!(:serializer)   { SellerService::SellerSerializer.new(seller: seller, sellers: seller)}

  it 'returns a specific seller for the show page' do
    response = serializer.show[:seller]
    expect(response).to_not be_nil
    expect(response[:name]).to eq(sv.name)
    expect(response[:status]).to eq(seller.status)
  end

  it 'returns all sellers for the index page' do
    sellers = [seller, seller_2, seller_3]
    new_serializer = SellerService::SellerSerializer.new(seller: seller, sellers: sellers)
    response = new_serializer.index[:sellers]
    expect(response.count).to eq(3)
    expect(response.first[:id]).to eq(sellers.first.id)
    expect(response.second[:id]).to eq(sellers.second.id)
    expect(response.third[:id]).to eq(sellers.third.id)
  end
end
