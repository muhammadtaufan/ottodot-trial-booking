class Student < ApplicationRecord
  belongs_to :parent
  has_many :bookings
end
