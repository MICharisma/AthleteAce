FactoryBot.define do
  factory :division do
    sequence(:name) { |n| "Division #{n}" }
    association :conference
    league { conference&.league || association(:league) }
    
    trait :with_teams do
      transient do
        teams_count { 4 }
      end
      
      after(:create) do |division, evaluator|
        create_list(:team, evaluator.teams_count, league: division.league).each do |team|
          create(:membership, team: team, division: division)
        end
      end
    end
  end
end
