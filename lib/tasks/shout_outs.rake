namespace :shout_outs do
  desc "Seed development Feed posts, wallet bids, and unpaid checkouts without calling Stripe"
  task seed_demo: :environment do
    abort "This task requires the development environment." unless Rails.env.development?

    examples = [
      [ "Celtics", 25, :credit, "Love how quickly the ball moves when everyone makes the extra pass." ],
      [ "Warriors", 125, :credit, "The off-ball screens are half the fun of watching this team." ],
      [ "Heat", 300, :credit, "The way this team finds shooters in the corners is worth watching twice." ],
      [ "Dodgers", 750, :credit, "Nothing like the whole park getting loud with two strikes." ],
      [ "Marlins", 50, :paid, "Here's to every kid who stayed for the last out and got a ball after the game." ],
      [ "Yankees", 475, :paid, "The outfield deserves a shout-out for making those deep drives look routine." ],
      [ "Florida Panthers", 1200, :paid, "Great example of how a hard forecheck can tilt the whole game." ],
      [ "Lightning", 2500, :paid, "The penalty kill is my favorite part of watching this team. Every clear feels earned." ],
      [ "Dolphins", 225, :declined, "The receivers' timing on those quick routes is so much fun to watch." ],
      [ "Magic", 1600, :declined, "A shout-out for the hustle on the glass. Those extra possessions add up." ]
    ]
    teams = examples.to_h do |mascot, *|
      team = mascot == "Florida Panthers" ? Team.find_by!(territory: "Florida", mascot: "Panthers") : Team.find_by!(mascot: mascot)
      [ mascot, team ]
    end

    accounts = [
      [ "Rosa Bennett", "rosa_on_the_road", false ],
      [ "Julian Park", "julian_box_score", false ],
      [ "Morgan Ellis", "morgan_feed_review", true ]
    ]
    posts = ShoutOut.transaction do
      rosa, julian, reviewer = accounts.map do |name, handle, moderator|
        email = "#{handle}@feed.example.com"
        Ace.find_by(email: email) || FactoryBot.create(:ace, email: email, username: handle,
          display_name: name, moderator: moderator, password: SecureRandom.hex(24), password_confirmation: nil)
      end
      rosa.with_lock do
        unless rosa.stripe_purchases.exists?(request_key: "demo-feed-wallet")
          FactoryBot.create(:stripe_purchase, :paid, ace: rosa, amount_cents: 5000, request_key: "demo-feed-wallet")
        end
        examples.map do |mascot, bid_cents, funding, message|
          ace = funding == :credit ? rosa : julian
          target = teams.fetch(mascot)
          draft = ace.shout_out_drafts.find_by(target: target, message: message) ||
            FactoryBot.create(:shout_out_draft, ace: ace, target: target, message: message)
          post = ShoutOutSubmission.call(draft: draft, revision: draft.lock_version, bid_cents: bid_cents,
            payment_method: funding == :credit ? "credit" : "stripe")
          unless funding == :credit || post.stripe_purchases.exists?
            FactoryBot.create(:stripe_purchase, funding, ace: ace, shout_out: post, amount_cents: bid_cents)
            post.reload
          end
          if post.funding_status == "reserved" && post.moderation_status == "pending"
            Moderation::Review.call(record: post, actor: reviewer, action: "approve",
              revision: post.moderation_revision, status: post.moderation_status)
          end
          post
        end
      end
    end
    puts "#{ShoutOut.live.where(id: posts).count} live shout-outs, #{posts.count { |post| post.funding_status == "unfunded" }} awaiting payment."
  end
end
