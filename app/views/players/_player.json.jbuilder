json.extract! player, :id, :name, :short_name, :name_segments, :first_name, :last_name, :nicknames, :alternate_names, :birthdate, :birth_city_id, :birth_country_id, :current_position, :debut_year, :draft_year, :active, :bio, :photo_urls, :team_id, :created_at, :updated_at
json.url player_url(player, format: :json)
