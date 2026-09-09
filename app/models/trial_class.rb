class TrialClass < ApplicationRecord
  has_many :bookings

  def seats_remaining(confirmed_count = 0)
    capacity - confirmed_count
  end
end
