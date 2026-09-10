FactoryBot.define do
  factory :booking do
    student { association :student }
    trial_class { association :trial_class }
    status { :pending_payment }

    trait :pending_payment do
      status { :pending_payment }
    end

    trait :confirmed do
      status { :confirmed }
    end

    trait :payment_failed do
      status { :payment_failed }
    end

    trait :seat_unavailable do
      status { :seat_unavailable }
    end
  end
end
