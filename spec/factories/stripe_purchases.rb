FactoryBot.define do
  factory :stripe_purchase do
    ace
    amount_cents { 1000 }
    request_key { SecureRandom.uuid }

    trait :paid do
      after(:create) do |purchase|
        purchase.fulfill!(
          "id" => "cs_test_#{purchase.id}", "mode" => "payment", "payment_status" => "paid", "currency" => "usd",
          "amount_total" => purchase.amount_cents, "client_reference_id" => "athleteace:#{purchase.id}",
          "metadata" => { "ace_id" => purchase.ace_id.to_s },
          "payment_intent" => "pi_test_#{purchase.id}"
        )
      end
    end

    trait :declined do
      stripe_session_id { "cs_test_declined_#{request_key}" }
    end
  end
end
