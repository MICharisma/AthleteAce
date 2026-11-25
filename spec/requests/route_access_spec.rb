require "rails_helper"

# Who can reach every route. Each route is listed under its audience:
#
#   everyone    a signed-out visitor reaches it
#   signed_in   a signed-out visitor is sent to sign in; any fan reaches it
#   reviewer    a fan is refused; a moderator reaches it
#   admin       a moderator is refused; an admin reaches it
#   credential  callers prove themselves with a token, signature or OAuth
#               response, so even an admin session without one is turned away
#   rizz        present only while Sign in with Rizz is on
#
# Requests use a placeholder id for every record, so "reaches" means the
# guards let the request through, whatever the action then does with the id.
# A route that isn't listed fails the last example, so a new route can't ship
# without deciding who may use it.
RSpec.describe "Route access", type: :request do
  ACCESS = {
    everyone: <<~ROUTES,
      GET /aces/sign_in
      POST /aces/sign_in
      DELETE /aces/sign_out
      POST /aces/auth/google_oauth2
      GET /aces/password/new
      PATCH /aces/password
      PUT /aces/password
      POST /aces/password
      GET /aces/cancel
      GET /aces/sign_up
      POST /aces
      GET /aces/confirmation/new
      GET /aces/confirmation
      POST /aces/confirmation
      GET /sports
      GET /sports/:id
      GET /leagues
      GET /leagues/:id
      GET /conferences
      GET /conferences/:id
      GET /divisions
      GET /divisions/:id
      GET /teams
      GET /teams/:id
      GET /players/:player_id/shout_outs
      GET /players
      GET /players/:id
      GET /figures/:id
      GET /businesses
      GET /businesses/:id
      GET /practices
      GET /practices/:id
      GET /protocols
      GET /protocols/:id
      GET /topics
      GET /topics/:id
      GET /organizations
      GET /organizations/:id
      GET /memberships
      GET /memberships/:id
      GET /organization_affiliations
      GET /organization_affiliations/:id
      GET /seasons
      GET /seasons/:id
      GET /years
      GET /years/:id
      GET /campaigns
      GET /campaigns/:id
      GET /contests
      GET /contests/:id
      GET /games
      GET /games/:id
      GET /contracts
      GET /contracts/:id
      GET /activations
      GET /activations/:id
      GET /countries
      GET /countries/:id
      GET /states
      GET /states/:id
      GET /cities
      GET /cities/:id
      GET /stadiums
      GET /stadiums/:id
      GET /federations
      GET /federations/:id
      GET /sports/:sport_id/players
      GET /sports/:sport_id/players/:id
      GET /leagues/:league_id/players
      GET /leagues/:league_id/players/:id
      GET /stadiums/:stadium_id/players
      GET /stadiums/:stadium_id/players/:id
      GET /teams/:team_id/players
      GET /teams/:team_id/players/:id
      GET /states/:state_id/players
      GET /states/:state_id/players/:id
      GET /cities/:city_id/players
      GET /cities/:city_id/players/:id
      GET /conferences/:conference_id/divisions
      GET /conferences/:conference_id/divisions/:id
      GET /leagues/:league_id/divisions
      GET /leagues/:league_id/divisions/:id
      GET /countries/:country_id/divisions
      GET /countries/:country_id/divisions/:id
      GET /sports/:sport_id/divisions
      GET /sports/:sport_id/divisions/:id
      GET /contests/:contest_id/divisions
      GET /contests/:contest_id/divisions/:id
      GET /leagues/:league_id/conferences
      GET /leagues/:league_id/conferences/:id
      GET /countries/:country_id/conferences
      GET /countries/:country_id/conferences/:id
      GET /sports/:sport_id/conferences
      GET /sports/:sport_id/conferences/:id
      GET /stadiums/:stadium_id/conferences
      GET /stadiums/:stadium_id/conferences/:id
      GET /contests/:contest_id/conferences
      GET /contests/:contest_id/conferences/:id
      GET /states/:state_id/cities
      GET /states/:state_id/cities/:id
      GET /countries/:country_id/cities
      GET /countries/:country_id/cities/:id
      GET /teams/:team_id/memberships
      GET /teams/:team_id/memberships/:id
      GET /divisions/:division_id/memberships
      GET /divisions/:division_id/memberships/:id
      GET /conferences/:conference_id/memberships
      GET /conferences/:conference_id/memberships/:id
      GET /leagues/:league_id/memberships
      GET /leagues/:league_id/memberships/:id
      GET /sports/:sport_id/memberships
      GET /sports/:sport_id/memberships/:id
      GET /countries/:country_id/memberships
      GET /countries/:country_id/memberships/:id
      GET /states/:state_id/memberships
      GET /states/:state_id/memberships/:id
      GET /cities/:city_id/memberships
      GET /cities/:city_id/memberships/:id
      GET /stadiums/:stadium_id/memberships
      GET /stadiums/:stadium_id/memberships/:id
      GET /teams/:team_id/campaigns
      GET /teams/:team_id/campaigns/:id
      GET /seasons/:season_id/campaigns
      GET /seasons/:season_id/campaigns/:id
      GET /leagues/:league_id/campaigns
      GET /leagues/:league_id/campaigns/:id
      GET /sports/:sport_id/campaigns
      GET /sports/:sport_id/campaigns/:id
      GET /countries/:country_id/campaigns
      GET /countries/:country_id/campaigns/:id
      GET /states/:state_id/campaigns
      GET /states/:state_id/campaigns/:id
      GET /cities/:city_id/campaigns
      GET /cities/:city_id/campaigns/:id
      GET /stadiums/:stadium_id/campaigns
      GET /stadiums/:stadium_id/campaigns/:id
      GET /seasons/:season_id/contests
      GET /seasons/:season_id/contests/:id
      GET /leagues/:league_id/contests
      GET /leagues/:league_id/contests/:id
      GET /conferences/:conference_id/contests
      GET /conferences/:conference_id/contests/:id
      GET /divisions/:division_id/contests
      GET /divisions/:division_id/contests/:id
      GET /sports/:sport_id/contests
      GET /sports/:sport_id/contests/:id
      GET /countries/:country_id/contests
      GET /countries/:country_id/contests/:id
      GET /states/:state_id/contests
      GET /states/:state_id/contests/:id
      GET /cities/:city_id/contests
      GET /cities/:city_id/contests/:id
      GET /stadiums/:stadium_id/contests
      GET /stadiums/:stadium_id/contests/:id
      GET /cities/:city_id/stadiums
      GET /cities/:city_id/stadiums/:id
      GET /states/:state_id/stadiums
      GET /states/:state_id/stadiums/:id
      GET /countries/:country_id/stadiums
      GET /countries/:country_id/stadiums/:id
      GET /sports/:sport_id/stadiums
      GET /sports/:sport_id/stadiums/:id
      GET /countries/:country_id/sports
      GET /countries/:country_id/sports/:id
      GET /sports/:sport_id/teams
      GET /sports/:sport_id/teams/:id
      GET /leagues/:league_id/teams
      GET /leagues/:league_id/teams/:id
      GET /conferences/:conference_id/teams
      GET /conferences/:conference_id/teams/:id
      GET /divisions/:division_id/teams
      GET /divisions/:division_id/teams/:id
      GET /states/:state_id/teams
      GET /states/:state_id/teams/:id
      GET /cities/:city_id/teams
      GET /cities/:city_id/teams/:id
      GET /stadiums/:stadium_id/teams
      GET /stadiums/:stadium_id/teams/:id
      GET /sports/:sport_id/countries
      GET /sports/:sport_id/countries/:id
      GET /contests/:contest_id/countries
      GET /contests/:contest_id/countries/:id
      GET /sports/:sport_id/leagues
      GET /sports/:sport_id/leagues/:id
      GET /countries/:country_id/leagues
      GET /countries/:country_id/leagues/:id
      GET /contests/:contest_id/leagues
      GET /contests/:contest_id/leagues/:id
      GET /countries/:country_id/states
      GET /countries/:country_id/states/:id
      GET /sports/:sport_id/states
      GET /sports/:sport_id/states/:id
      GET /contests/:contest_id/seasons
      GET /contests/:contest_id/seasons/:id
      GET /organizations/:organization_id/contracts
      GET /organizations/:organization_id/contracts/:id
      GET /players/:player_id/contracts
      GET /players/:player_id/contracts/:id
      GET /teams/:team_id/contracts
      GET /teams/:team_id/contracts/:id
      GET /sports/:sport_id/contracts
      GET /sports/:sport_id/contracts/:id
      GET /leagues/:league_id/contracts
      GET /leagues/:league_id/contracts/:id
      GET /conferences/:conference_id/contracts
      GET /conferences/:conference_id/contracts/:id
      GET /divisions/:division_id/contracts
      GET /divisions/:division_id/contracts/:id
      GET /states/:state_id/contracts
      GET /states/:state_id/contracts/:id
      GET /cities/:city_id/contracts
      GET /cities/:city_id/contracts/:id
      GET /stadiums/:stadium_id/contracts
      GET /stadiums/:stadium_id/contracts/:id
      GET /contracts/:contract_id/activations
      GET /contracts/:contract_id/activations/:id
      GET /campaigns/:campaign_id/activations
      GET /campaigns/:campaign_id/activations/:id
      GET /players/:player_id/activations
      GET /players/:player_id/activations/:id
      GET /teams/:team_id/activations
      GET /teams/:team_id/activations/:id
      GET /seasons/:season_id/activations
      GET /seasons/:season_id/activations/:id
      GET /leagues/:league_id/activations
      GET /leagues/:league_id/activations/:id
      GET /sports/:sport_id/activations
      GET /sports/:sport_id/activations/:id
      GET /states/:state_id/activations
      GET /states/:state_id/activations/:id
      GET /cities/:city_id/activations
      GET /cities/:city_id/activations/:id
      GET /stadiums/:stadium_id/activations
      GET /stadiums/:stadium_id/activations/:id
      GET /spectrums
      GET /spectrums/:id
      GET /players/:player_id/ratings/for_spectrums
      GET /teams/:team_id/ratings/for_spectrums
      GET /divisions/:division_id/ratings/for_spectrums
      GET /achievements
      GET /achievements/:id
      GET /quests
      GET /quests/:id
      GET /play/preview
      POST /play/preview
      GET /strength
      GET /play/flash-cards
      GET /play/rounds/new
      GET /design/tokens
      GET /feed
      GET /feed/leaders
      GET /feed/posts/:id
      GET /player_groups
      GET /player_groups/:id
      GET /browse
      PATCH /theme_preference
      PUT /theme_preference
      GET /search
      GET /faq
      GET /contact
      GET /
    ROUTES
    signed_in: <<~ROUTES,
      GET /aces/password/edit
      GET /aces/edit
      PATCH /aces
      PUT /aces
      DELETE /aces
      GET /profile/edit
      GET /profile
      PATCH /profile
      PUT /profile
      GET /ratings
      POST /ratings
      GET /ratings/new
      GET /ratings/:id/edit
      GET /ratings/:id
      PATCH /ratings/:id
      PUT /ratings/:id
      DELETE /ratings/:id
      GET /spectrums/:spectrum_id/ratings
      POST /spectrums
      GET /spectrums/new
      GET /players/:player_id/ratings/dimension
      POST /players/:player_id/ratings/suggest_dimensions
      POST /players/:player_id/ratings
      GET /players/:player_id/ratings/new
      GET /teams/:team_id/ratings/dimension
      POST /teams/:team_id/ratings/suggest_dimensions
      POST /teams/:team_id/ratings
      GET /teams/:team_id/ratings/new
      GET /divisions/:division_id/ratings/dimension
      POST /divisions/:division_id/ratings/suggest_dimensions
      POST /divisions/:division_id/ratings
      GET /divisions/:division_id/ratings/new
      GET /achievements/target_options
      POST /achievements
      GET /achievements/new
      POST /quests/:quest_id/highlights
      GET /quests/:quest_id/highlights/new
      GET /quests/:quest_id/highlights/:id/edit
      PATCH /quests/:quest_id/highlights/:id
      PUT /quests/:quest_id/highlights/:id
      DELETE /quests/:quest_id/highlights/:id
      POST /quests/:quest_id/goals
      GET /quests/random
      POST /quests
      GET /quests/new
      GET /quests/:id/edit
      PATCH /quests/:id
      PUT /quests/:id
      DELETE /quests/:id
      POST /highlights
      GET /highlights/new
      GET /goals
      GET /goals/:id
      PATCH /goals/:id
      PUT /goals/:id
      DELETE /goals/:id
      POST /play/quick
      POST /play/drill-misses
      POST /play/rounds/:id/answer
      POST /play/rounds/:id/advance
      POST /play/rounds/:id/pause
      POST /play/rounds/:id/resume
      POST /play/rounds/:id/drill
      GET /play/rounds/:id/summary
      POST /play/rounds
      GET /play/rounds/:id
      GET /strength/multiple_choice
      GET /strength/phased_repetition
      GET /strength/images
      GET /strength/ciphers
      GET /strength/team_match
      GET /strength/game_attempts
      GET /strength/teams/:team_id/game_attempts
      POST /strength/check_answer
      GET /play/guess-the-division
      POST /play/guess-the-division
      PATCH /play/guess-the-division
      GET /game_attempts
      POST /game_attempts
      GET /wallet
      POST /wallet
      POST /stripe_purchases/:id/pay
      GET /stripe_purchases/:id
      POST /shout_outs/:id/pay
      POST /shout_outs/:id/copy_to_draft
      POST /shout_outs/:shout_out_id/reports
      GET /shout_outs/:shout_out_id/reports/new
      PATCH /shout_outs/:shout_out_id/reactions/:kind
      PUT /shout_outs/:shout_out_id/reactions/:kind
      DELETE /shout_outs/:shout_out_id/reactions/:kind
      GET /shout_outs
      POST /shout_outs
      GET /shout_outs/:id
      GET /feed/drafts/targets
      GET /feed/drafts
      POST /feed/drafts
      GET /feed/drafts/new
      GET /feed/drafts/:id/edit
      PATCH /feed/drafts/:id
      PUT /feed/drafts/:id
      DELETE /feed/drafts/:id
      POST /follows
      DELETE /follows/:id
      GET /account/posting
      POST /moderate/aces/:ace_profile_id/posting_actions
    ROUTES
    reviewer: <<~ROUTES,
      GET /moderate/aces/:id
      GET /moderate
      GET /moderate/log
      GET /moderate/escalations
      POST /moderate/escalations
      GET /moderate/escalations/:id
      PATCH /moderate/escalations/:id
      PUT /moderate/escalations/:id
      GET /moderate/reports
      GET /moderate/reports/:id
      PATCH /moderate/reports/:id
      PUT /moderate/reports/:id
      GET /moderate/:type/:id
      PATCH /moderate/:type/:id
      POST /moderate/:type/:id/compare
    ROUTES
    admin: <<~ROUTES,
      GET /spectrums/:id/edit
      PATCH /spectrums/:id
      PUT /spectrums/:id
      DELETE /spectrums/:id
      GET /achievements/:id/edit
      PATCH /achievements/:id
      PUT /achievements/:id
      DELETE /achievements/:id
      POST /player_groups
      GET /player_groups/new
      GET /player_groups/:id/edit
      PATCH /player_groups/:id
      PUT /player_groups/:id
      DELETE /player_groups/:id
      GET /admin/content-catalog
      GET /admin/moderation-oversight
      GET /admin/player-history/:id
      GET /admin/competitions
      GET /admin/competitions/:id
      GET /admin/games
      GET /admin/games/:id
      GET /admin/people
      GET /admin/people/:id
      PATCH /admin/people/:id
      PUT /admin/people/:id
      GET /admin/sports-data
      POST /admin/sports-data
      GET /admin/sports-data/new
      GET /admin/sports-data/:id/edit
      PATCH /admin/sports-data/:id
      PUT /admin/sports-data/:id
      POST /admin/shots/:shot_id/captures
      PATCH /admin/shots/:shot_id/captures/:id
      PUT /admin/shots/:shot_id/captures/:id
      DELETE /admin/shots/:shot_id/captures/:id
      GET /admin/shots
      POST /admin/shots
      GET /admin/shots/:id/edit
      PATCH /admin/shots/:id
      PUT /admin/shots/:id
      GET /admin/catalog_edits
      GET /admin/catalog_edits/:id
      PATCH /admin/catalog_edits/:id
      PUT /admin/catalog_edits/:id
      GET /admin/claims
      GET /admin/claims/:kind/new
      POST /admin/claims/:kind
      GET /admin/claims/:kind/:id
      GET /admin/claims/:kind/:id/edit
      PATCH /admin/claims/:kind/:id
      POST /admin/claims/:kind/:id/review
      GET /admin/claims/:kind/:claim_id/attestations/new
      POST /admin/claims/:kind/:claim_id/attestations
      GET /admin/claims/:kind/:claim_id/attestations/:id/edit
      PATCH /admin/claims/:kind/:claim_id/attestations/:id
      DELETE /admin/claims/:kind/:claim_id/attestations/:id
      GET /admin/claim-identities
      GET /admin/claim-identities/:kind/new
      POST /admin/claim-identities/:kind
      GET /admin
      GET /admin/revenue
    ROUTES
    credential: <<~ROUTES,
      GET|POST /aces/auth/google_oauth2/callback
      POST /stripe/webhook
      POST /api/v1/shots
    ROUTES
    rizz: <<~ROUTES,
      POST /auth/rizz
      GET /auth/rizz/callback
      POST /auth/rizz/claim/start
      GET /auth/rizz/claim/prove
      POST /auth/rizz/claim/verify_password
      GET /auth/rizz/claim/google/callback
      GET /auth/rizz/claim/confirm
      POST /auth/rizz/claim/confirm
      POST /auth/rizz/claim/cancel
      POST /auth/rizz/create/start
      GET /auth/rizz/create
      POST /auth/rizz/create
      POST /auth/rizz/create/cancel
      POST /auth/rizz/claim/exchange
      POST /auth/rizz/usernames/check
      POST /auth/rizz/backchannel_logout
    ROUTES
  }.transform_values { |routes| routes.lines(chomp: true) }.freeze

  PLACEHOLDER_ID = "0198a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b".freeze

  def request_route(route)
    verb, spec = route.split(" ", 2)
    path = spec.gsub(/\([^)]*\)/, "").gsub(":kind", "business").gsub(/:\w+/, PLACEHOLDER_ID)
    send verb.split("|").first.downcase, path
    location = response.location.to_s
    return :login if response.status == 401 || URI(location).path == new_ace_session_path
    # require_admin! redirects HTML requests back with an "Only admins" alert.
    return :forbidden if response.status == 403 || flash[:alert].to_s.start_with?("Only admins")
    response.status >= 400 && response.status != 404 ? :rejected : :reached
  rescue StandardError
    # The action raised, so the guards had already let the request through.
    :reached
  end

  def sign_in_as(role) = sign_in(create(:ace, moderator: role == :moderator, admin: role == :admin))

  ACCESS[:everyone].each do |route|
    it("lets a signed-out visitor reach #{route}") { expect(request_route(route)).not_to be_in(%i[login forbidden]) }
  end

  ACCESS[:signed_in].each do |route|
    describe route do
      it("sends a signed-out visitor to sign in") { expect(request_route(route)).to eq(:login) }
      it "lets a fan reach it" do
        sign_in_as :fan
        expect(request_route(route)).not_to be_in(%i[login forbidden])
      end
    end
  end

  { reviewer: [ :fan, :moderator ], admin: [ :moderator, :admin ] }.each do |audience, (refused, allowed)|
    ACCESS[audience].each do |route|
      describe route do
        it "refuses a #{refused}" do
          sign_in_as refused
          expect(request_route(route)).to eq(:forbidden)
        end

        it "lets #{allowed == :admin ? 'an' : 'a'} #{allowed} reach it" do
          sign_in_as allowed
          expect(request_route(route)).not_to be_in(%i[login forbidden])
        end
      end
    end
  end

  ACCESS[:credential].each do |route|
    it("turns away an admin session without credentials at #{route}") do
      sign_in_as :admin
      expect(request_route(route)).to be_in(%i[login rejected])
    end
  end

  ACCESS[:rizz].each do |route|
    it("hides #{route} while Sign in with Rizz is off") do
      allow(RizzSignIn).to receive(:enabled?).and_return(false)
      allow(RizzSignIn.configuration).to receive(:configured?).and_return(false)
      verb, spec = route.split(" ", 2)
      send verb.downcase, spec.gsub(/:\w+/, PLACEHOLDER_ID)
      # The claim strategy answers its Google callback before routing, by
      # redirecting to the claim page, which is hidden too.
      hidden = response.not_found? || URI(response.location.to_s).path.start_with?("/auth/rizz/")
      expect(hidden).to be(true), "#{route} answered #{response.status} #{response.location}"
    end
  end

  it "classifies every application route" do
    routes = Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller].to_s
      next if controller.empty? || controller.start_with?("rails/", "active_storage", "action_mailbox", "turbo/")
      "#{route.verb} #{route.path.spec.to_s.delete_suffix('(.:format)')}"
    end
    unlisted = routes.uniq - ACCESS.values.flatten
    expect(unlisted).to be_empty, "Add these routes to ACCESS in spec/requests/route_access_spec.rb: #{unlisted.join(', ')}"
  end
end
