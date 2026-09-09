class Booking < ApplicationRecord
  belongs_to :student
  belongs_to :trial_class
  has_many :payment_attempts

  enum :status, { pending_payment: 0, confirmed: 1, payment_failed: 2, seat_unavailable: 3 }

  scope :confirmed, -> { where(status: :confirmed) }
end
