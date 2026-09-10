FactoryBot.define do
  factory :payment_attempt do
    booking { association :booking }
    status { :succeeded }
    amount_cents { nil }
    note { nil }
  end
end
