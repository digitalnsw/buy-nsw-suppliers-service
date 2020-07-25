require 'rails_helper'

RSpec.describe SellerService::SellerAddress do
  subject { described_class.new(attributes) }

  let(:attributes) { attributes_for(:seller_address) }

  describe '#initialize' do
    it 'can be initialized with attributes' do
      expect(subject.address).to eq(attributes[:address])
      expect(subject.suburb).to eq(attributes[:suburb])
      expect(subject.state).to eq(attributes[:state])
      expect(subject.postcode).to eq(attributes[:postcode])
      expect(subject.country).to eq(attributes[:country])
    end
  end

  describe "#to_h" do
    it 'includes the `state` field' do
      expect(subject.to_h[:state]).to eq(attributes[:state])
    end
  end

  describe 'ActiveModel behaviour' do
    it 'responds to #persisted?' do
      expect(subject).to respond_to(:persisted?)
    end

    it 'it is always persisted' do
      expect(subject.persisted?).to eq(true)
    end

    it 'responds to #id' do
      expect(subject).to respond_to(:id)
    end
  end
end
