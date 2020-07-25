require 'rails_helper'

RSpec.describe SellerService::DocumentExpiryService do
  let(:version) do
    create(
      :approved_seller_version,
      financial_statement_expiry: Date.today + 4.weeks,
      workers_compensation_certificate_expiry: Date.today + 5.weeks,
      product_liability_certificate_expiry: Date.today,
    )
  end

  subject { SellerService::DocumentExpiryService.new(seller_version: version) }

  describe '#expiring_or_expired_documents' do
    it 'returns the expiry dates for the documents' do
      expect(subject.expiring_or_expired_documents).to eq({
        financial_statement: 4.weeks,
        workers_compensation_certificate: 5.weeks,
        product_liability_certificate: 0.days,
      })
    end
  end

  describe '#alerting_documents' do
    it 'returns the relevant expiry alerts for the documents' do
      expect(subject.alerting_documents).to eq({
        financial_statement: 4.weeks,
      })
    end
  end

  describe '#expired_documents' do
    it 'returns the relevant expiry alerts for the documents' do
      expect(subject.expired_documents).to eq({
        product_liability_certificate: 0.days,
      })
    end
  end

  describe '#documents_serializable' do
    it 'returns the hash or expiring or expired documents' do
      expect(subject.documents_serializable).to eq([
        { name: 'financial_statement', expiry: '28 days' },
        { name: 'workers_compensation_certificate', expiry: '35 days' },
        { name: 'product_liability_certificate', expiry: 'Now expired' },
      ])
    end
  end

  describe '#just_expired_documents' do
    it 'returns all documents that have just expired' do
      expect(subject.just_expired_documents).to eq({
        product_liability_certificate: 0.days,
      })
    end
  end
end
