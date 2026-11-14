FactoryBot.define do
  factory :practice do
    name { %w[Meditation Prayer Gratitude Exercise Journaling Breathwork].sample }
    entity_code { "PRACTICE-#{SecureRandom.uuid.upcase}" }
  end

  factory :protocol do
    name { "Morning walk" }
    routine { "A walk outdoors before breakfast" }
    entity_code { "PROTOCOL-#{SecureRandom.uuid.upcase}" }
  end

  factory :figure_practice_relationship do
    figure
    predicate { "participates_in" }
    entity_code { "PRACTICE_TIE-#{SecureRandom.uuid.upcase}" }
  end

  factory :practice_connection do
    figure_practice_relationship
    practice
    entity_code { "PRACTICE_CONNECTION-#{SecureRandom.uuid.upcase}" }
  end
end
