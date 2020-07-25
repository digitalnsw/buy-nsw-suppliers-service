require 'rails_helper'

RSpec.describe SellerService::Document do
  let(:documentable) { create(:inactive_seller) }
  let(:attributes) { attributes_for(:document) }

  describe '#valid?' do
    context 'with all attributes' do
      subject { SellerService::Document.new(attributes) }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'without a document' do
      subject { SellerService::Document.new(attributes.merge(document: nil)) }

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors.keys).to include(:document)
      end
    end

    describe 'immutability' do
      context 'on create' do
        subject { SellerService::Document.new(attributes) }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'on update with changes' do
        subject { SellerService::Document.create!(attributes) }

        before(:each) do
          subject.original_filename = 'foo.jpg'
        end

        it 'is invalid' do
          expect(subject).not_to be_valid
          expect(subject.errors).to include(:base)
        end
      end

      context 'on update with only scan_status changes' do
        subject { SellerService::Document.create!(attributes) }

        before(:each) do
          subject.scan_status = :clean
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end
    end
  end

  describe '#scan_status' do
    it 'is unscanned by default' do
      expect(SellerService::Document.new.scan_status).to eq('unscanned')
    end
  end

  describe '#mark_as_clean!' do
    subject { SellerService::Document.create!(attributes) }

    it 'sets the scan_status to clean' do
      expect(subject.mark_as_clean!).to be_truthy
      expect(subject.reload.scan_status).to eq('clean')
    end
  end

  describe '#mark_as_infected!' do
    subject { SellerService::Document.create!(attributes) }

    it 'sets the scan_status to infected' do
      expect(subject.mark_as_infected!).to be_truthy
      expect(subject.reload.scan_status).to eq('infected')
    end
  end

  describe '#reset_scan_status!' do
    context 'when infected' do
      subject { SellerService::Document.create!(attributes) }

      before(:each) do
        subject.mark_as_infected!
      end

      it 'resets the scan_status to unscanned' do
        expect(subject.reset_scan_status!).to be_truthy
        expect(subject.reload.scan_status).to eq('unscanned')
      end
    end

    context 'when clean' do
      subject { SellerService::Document.create!(attributes) }

      before(:each) do
        subject.mark_as_clean!
      end

      it 'resets the scan_status to unscanned' do
        expect(subject.reset_scan_status!).to be_truthy
        expect(subject.reload.scan_status).to eq('unscanned')
      end
    end
  end

  describe '#update_document_attributes' do
    context 'on create' do
      subject { SellerService::Document.create!(attributes).reload }

      let(:file) { attributes[:document] }

      it 'sets the content_type' do
        expect(subject.content_type).to eq(file.content_type)
      end

      it 'sets the original_filename' do
        expect(subject.original_filename).to eq(file.original_filename)
      end

      it 'has the correct document size - see example.pdf for size' do
        expect(subject.size).to eq(23843)
      end

      it 'has the correct extension' do
        expect(subject.extension).to eq("PDF")
      end

      it 'creates a url that points to the file' do
        expect(subject.url).to_not be_blank
      end

      it 'should have the correct mime_type' do
        expect(subject.mime_type).to eq("application/pdf")
      end

    end
  end
end

