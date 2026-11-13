FactoryBot.define do
  factory :position_assignment do
    association :subject, factory: :player
    position { association :position, sport: subject.sport }
  end
end
