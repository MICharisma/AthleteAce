FactoryBot.define do
  factory :topic do
    sequence(:name) { |n| "#{%w[Discipline Leadership Faith Resilience Family].sample} #{n}" }
    entity_code { "TOPIC-#{SecureRandom.uuid.upcase}" }
  end

  factory :attributed_statement do
    figure
    attribution_kind { "direct_quote" }
    text { "Show up for the people next to you." }
    entity_code { "STATEMENT-#{SecureRandom.uuid.upcase}" }

    trait :observer_characterization do
      attribution_kind { "observer_characterization" }
      observer_name { Faker::Name.name }
      text { "Described as the first one in the gym every morning." }
    end
  end
end
