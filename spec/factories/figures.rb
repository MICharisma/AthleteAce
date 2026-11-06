FactoryBot.define do
  factory :figure do
    name { Faker::Name.name }
    entity_code { "FIGURE-#{SecureRandom.uuid.upcase}" }
  end
end
