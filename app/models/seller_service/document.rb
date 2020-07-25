module SellerService
  class Document < SellerService::ApplicationRecord
    self.table_name = 'documents'
    include AASM
    extend Enumerize

    enumerize :scan_status, in: [:unscanned, :clean, :infected]

    mount_uploader :document, DocumentUploader

    after_commit :scan_file, on: :create
    before_create :update_document_attributes

    validates :document, :scan_status, presence: true
    validate :force_immutable

    aasm column: :scan_status do
      state :unscanned, initial: true
      state :clean
      state :infected

      event :mark_as_clean do
        transitions from: :unscanned, to: :clean
      end

      event :mark_as_infected do
        transitions from: :unscanned, to: :infected
      end

      event :reset_scan_status do
        transitions from: [:clean, :infected], to: :unscanned
      end
    end

    def url
      document.url
    end

    def mime_type
      MIME::Types[content_type].first
    end

    def extension
      mime_type.preferred_extension.upcase
    end

    def size
      document.size
    end

    def scan_file
      # DocumentScanJob.perform_later(self)
    end

    private

    def force_immutable
      if changed? && persisted? && changes.keys != ['scan_status']
        errors.add(:base, :immutable)
        reload
      end
    end

    def update_document_attributes
      self.original_filename = document.file.original_filename
      self.content_type = document.file.content_type
    end
  end
end
