module SellerService
  class ApplicationJob < ActiveJob::Base
    # At the moment everything gets queued in the same queue
    queue_as ENV.fetch('MAILER_QUEUE_NAME', :default)

    rescue_from Exception do |exception|
      Airbrake.notify_sync exception
    end
  end
end
