FactoryBot.define do
  factory :trial_class do
    subject { "Math" }
    capacity { 4 }
    starts_at { 1.week.from_now }
  end
end
