require "rails_helper"

RSpec.describe "Team wall, reports and revenue" do
  let(:author) { create(:ace) }
  let(:reporter) { create(:ace) }
  let(:reviewer) { create(:ace, moderator: true) }
  let(:team) { create(:team, league: create(:mlb), territory: "Chicago", mascot: "Cubs", abbreviation: "CHC", primary_color: "#0E3386", secondary_color: "#CC3433") }
  let(:player) { create(:player, team: team, first_name: "Nico", last_name: "Hoerner") }
  let(:post) { submit_credit(ace: author, target: player, message: "Outstanding work in the final inning", bid: 125) }

  before do
    buy_credit(author)
    review_post(post, action: "approve", reviewer: reviewer)
  end

  def report
    ShoutOutReport.create!(shout_out: post, reporter: reporter, reason: "Off-topic", note: "Please check this against the team context")
  end

  def hide_reported_post
    Moderation::ResolveReports.call(post: post, actor: reviewer, action: "hide", revision: post.reload.moderation_revision,
      last_report_id: report.id, reason: "This post is off topic")
  end

  it "lets a fan report a player's post from the team wall" do
    sign_in reporter
    visit team_path(team, side: "feed")
    expect(page).to have_css("body[data-side='feed']")
    within('[aria-label="Wall filters"]') { click_link "Players" }
    within("#shout_out_#{post.id}") { click_link "Report" }
    select "Off-topic", from: "Reason"
    fill_in "Note (optional)", with: "Please check this against the team context"
    click_button "Send report"
    expect(page).to have_content("Report received.")
    expect(post.shout_out_reports.sole.reporter).to eq(reporter)
  end

  it "hides a reported post and refunds the author's full bid" do
    report
    sign_in reviewer
    visit reports_path
    expect(page).to have_content("1 report")
    click_link "Review reports"
    expect(page).to have_content("Please check this against the team context")
    fill_in "Decision reason", with: "This post is off topic"
    click_button "Hide and refund credit"
    expect(page).to have_content("Reports resolved.")
    expect(CreditAccount.for(author).available_cents).to eq(1000)
    visit team_path(team, side: "feed")
    expect(page).to have_content("No shout-outs here yet.")
  end

  it "shows a hidden post's refund in admin revenue and its decision on the report" do
    hide_reported_post
    sign_in create(:ace, admin: true)
    visit shout_out_revenue_path(days: 7)
    [ "Cash purchases", "Refunded to credit", "$10.00", "$1.25" ].each { |text| expect(page).to have_content(/#{Regexp.escape(text)}/i) }
    visit report_path(post)
    expect(page).to have_content("Hidden")
    expect(page).to have_content("This post is off topic")
  end
end
