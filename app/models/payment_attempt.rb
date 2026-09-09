class PaymentAttempt < ApplicationRecord
  belongs_to :booking

  enum :status, { succeeded: 0, failed: 1 }
end
