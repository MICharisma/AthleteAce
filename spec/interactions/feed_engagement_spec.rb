require "rails_helper"

RSpec.describe "Feed engagement" do

  it "searches public posts, reacts on Feed and walls, and reads weekly standings" do
    author = create(:ace)
    fan = create(:ace)
    team = create(:team, league: create(:mlb), territory: "Chicago", mascot: "Cubs", abbreviation: "CHC")
    nico = create(:player, team: team, first_name: "Nico", last_name: "Hoerner")
    pete = create(:player, team: team, first_name: "Pete", last_name: "Crow-Armstrong")
    buy_credit(author)
    post = submit_credit(ace: author, target: nico, message: "Tireless work in every inning", bid: 500)
    second = submit_credit(ace: author, target: nico, message: "A spectacular catch", bid: 1)
    third = submit_credit(ace: author, target: pete, message: "A brilliant finish", bid: 1)
    [ post, second, third ].each { |record| review_post(record, action: "approve") }
    visit feed_path
    fill_in "Search live shout-outs", with: "Tireless"
    click_button "Search posts"
    expect(page).to have_content(post.message)
    expect(page).not_to have_content(second.message)
    within("#shout_out_#{post.id}") { click_link "Permalink" }
    expect(page).to have_current_path(feed_post_path(post))
    expect(page).to have_link("Fire 0", href: new_ace_session_path)

    sign_in fan
    visit feed_post_path(post)
    within("#shout_out_#{post.id}") { find('button[aria-label="Fire, 0"]').click }
    expect(page).to have_css('button[aria-label="Fire, 1"][aria-pressed="true"]')
    find('button[aria-label="Fire, 1"]').click
    expect(page).to have_css('button[aria-label="Fire, 0"][aria-pressed="false"]')
    visit team_path(team, side: "feed")
    within("#shout_out_#{post.id}") { find('button[aria-label="Legend, 0"]').click }
    expect(page).to have_css('button[aria-label="Legend, 1"][aria-pressed="true"]')
    click_link "Leaders", match: :first
    expect(page).to have_content(/Most shouted/i)
    expect(page).to have_content("Nico Hoerner")
    expect(page).to have_content("2 shout-outs")
    find("summary", text: "Top shout-out for Nico Hoerner").click
    expect(page).to have_css('button[aria-label="Legend, 1"][aria-pressed="true"]')
    fan.update!(theme: "dark")
    visit shout_out_leaderboard_path
    expect(page).to have_css('html[data-theme="dark"]')
    expect(CreditAccount.for(author).available_cents).to eq(498)
  end
end
