FactoryBot.define do
  factory :attestation do
    claim factory: :figure_business_relationship
    content_form { "link" }
    url { "https://example.com/news/#{SecureRandom.hex(4)}" }
    source_title { "Partnership announcement" }
    publisher { "Example Sports Daily" }
    excerpt { "announced a multi-year partnership" }
    context { "The announcement names the athlete as the brand's partner." }
    entity_code { "ATTESTATION-#{SecureRandom.uuid.upcase}" }

    trait :text do
      content_form { "text" }
      url { nil }
      body { "My morning walk is an example of prayer and gratitude." }
    end

    trait :video do
      content_form { "video" }
      url { "https://example.com/videos/#{SecureRandom.hex(4)}" }
      locator { "04:12-04:40" }
    end
  end
end
