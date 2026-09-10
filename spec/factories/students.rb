FactoryBot.define do
  factory :student do
    name { "Alice Smith" }
    parent { association :parent }
  end
end
