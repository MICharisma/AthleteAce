FactoryBot.define do
  factory :shout_out_draft do
    ace
    association :target, factory: :team
    message { "That kind of defense keeps you in the game all night." }
  end
end
