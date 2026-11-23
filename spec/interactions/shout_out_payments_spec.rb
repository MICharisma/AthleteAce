require "rails_helper"

RSpec.describe "Shout-out payments and moderation" do
  before do
    @stripe_env = %w[STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET].to_h { |key| [ key, ENV[key] ] }
    ENV["STRIPE_SECRET_KEY"] = "sk_test_fixture"
    ENV["STRIPE_WEBHOOK_SECRET"] = "whsec_fixture"
    allow(StripeCheckout).to receive(:call) { |purchase:, return_url:| return_url }
  end

  after do
    @stripe_env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  context "with a credit balance" do
    let(:ace) { create(:ace) }
    let(:reviewer) { create(:ace, moderator: true) }
    let(:player) { create(:player, first_name: "Jalen", last_name: "Brunson") }
    let(:post) { ace.shout_outs.sole }

    before { buy_credit(ace) }

    def submit_with_credit
      submit_credit(ace: ace, target: player, message: "That fourth quarter was unforgettable!", bid: 250)
    end

    it "saves a draft from a player page and reserves a custom bid from credit" do
      sign_in ace
      visit player_path(player)
      click_link "Write a shout-out draft"
      fill_in "Your message", with: "That fourth quarter was unforgettable!"
      click_button "Save draft"
      expect(page).to have_content("Draft saved. Only you can see it.")
      within('[aria-labelledby="submit-shout-out-title"]') do
        fill_in "Your bid (USD)", with: "2.50"
        select "Use credit", from: "Payment method"
        click_button "Continue with bid"
      end
      expect(page).to have_content("In review. Your bid is reserved.")
      visit wallet_path
      expect(page).to have_css(".wallet-available", text: "$7.50")
      expect(page).to have_css(".wallet-reserved", text: "$2.50")
    end

    it "publishes the post to the feed once a reviewer approves it" do
      submit_with_credit
      using_session(:reviewer) do
        sign_in reviewer
        visit moderation_item_path(type: "ShoutOut", id: post.id)
        click_button "Approve"
        expect(page).to have_css(".browse-header .eyebrow", text: /approved/i)
      end
      using_session(:visitor) do
        visit feed_path
        expect(page).to have_css(".shout-out-card", text: post.message)
        expect(page).to have_no_content("in review")
      end
    end

    it "returns the full bid to credit when a reviewer hides the post" do
      submit_with_credit
      review_post(post, action: "approve", reviewer: reviewer)
      using_session(:reviewer) do
        sign_in reviewer
        visit moderation_item_path(type: "ShoutOut", id: post.id)
        fill_in "Reason or note", with: "Not about the target"
        click_button "Hide"
        expect(page).to have_css(".browse-header .eyebrow", text: /hidden/i)
      end
      sign_in ace # Devise signs in on the next request, so wait until the reviewer is done.
      visit wallet_path
      expect(page).to have_css(".wallet-available", text: "$10.00")
      expect(page).to have_css(".wallet-reserved", text: "$0.00")
      visit shout_out_path(post)
      expect(page).to have_content("full bid has been returned to your credit wallet")
    end
  end

  it "keeps a direct Stripe payment unfunded until confirmed and reserves its whole amount" do
    ace = create(:ace)
    target = create(:team, territory: "New York", mascot: "Knicks")
    draft = ace.shout_out_drafts.create!(target: target, message: "What a comeback!")
    sign_in ace
    visit edit_shout_out_draft_path(draft)
    fill_in "Your bid (USD)", with: "0.50"
    select "Pay directly with Stripe", from: "Payment method"
    click_button "Continue with bid"
    expect(page).to have_content("Awaiting payment")
    click_button "Pay with Stripe"
    expect(page).to have_content(/Awaiting payment confirmation/i)
    purchase = ace.stripe_purchases.sole
    expect(CreditEntry.count).to eq(0)
    purchase.fulfill!(paid_session(purchase))
    click_link "Refresh status"
    expect(page).to have_content(/Payment received/i)
    click_link "Credit wallet"
    expect(page).to have_css(".wallet-available", text: "$0.00")
    expect(page).to have_css(".wallet-reserved", text: "$0.50")
  end
end
