module SellerService::Concerns::Documentable
  extend ActiveSupport::Concern

  class_methods do
    def has_multi_documents(*fields)
      fields.each do |field|
        after_initialize do
          @documents = {}
        end

        define_method("#{field}s") do
          document_ids = send("#{field}_ids")

          @documents[field] ||= if document_ids.present?
                                  Document.where(id: document_ids).to_a
                                else
                                  []
                                end
        end

        define_method("#{field}s=") do |documents|
          # send("#{field}_ids=", documents.map(&:id))
        end

        define_method("#{field}_files") do
          public_send("#{field}s").map(&:document)
        end

        # before_save do
        #   @updated_documents.each do |key, docs|
        #     docs.each{|doc|doc.save!}
        #     send("#{key}_ids=", doc.map(&:id))
        #   end
        # end
      end
    end
  end

  included do
    private_class_method :has_multi_documents
  end
end
