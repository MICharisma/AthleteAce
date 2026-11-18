FactoryBot.define do
  factory :business do
    name { Faker::Company.name }
    entity_code { "BUSINESS-#{SecureRandom.uuid.upcase}" }

    trait :foundation do
      name { "#{Faker::Name.last_name} Family Foundation" }
    end

    trait :school do
      name { "#{Faker::Address.city} Preparatory School" }
    end
  end

  factory :figure_business_relationship do
    figure
    business
    predicate { "promotes" }
    entity_code { "BUSINESS_TIE-#{SecureRandom.uuid.upcase}" }

    trait :reported_current do
      temporal_state { "reported_current" }
      start_date { "2023" }
      as_of_date { "2026-10" }
    end

    trait :paid_sponsorship do
      predicate { "sponsored_by" }
      compensation { "documented_paid" }
      compensation_description { "Multi-year paid footwear sponsorship disclosed in the announcement" }
    end
  end
end
