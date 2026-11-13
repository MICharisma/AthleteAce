class SeedMemberships
  include SeedHelpers
  
  def self.run(glob_patterns)
    SeedHelpers.log_and_puts "\n----- Seeding Memberships -----"
    
    glob_patterns.each do |pattern|
      SeedHelpers.load_json_files(pattern).each do |file_data|
        SeedHelpers.log_and_puts "Loading memberships from #{SeedHelpers.relative_path(file_data[:path])}"
        
        league = League.find_by(name: file_data[:data]['league_name'])
        if league.nil?
          SeedHelpers.log_and_puts "Warning: League not found: #{file_data[:data]['league_name']}"
          next
        end
        
        file_data[:data]['memberships'].each do |membership_data|
          # Find team (try by territory + mascot first, then just mascot)
          team = if membership_data['territory_name']
            league.teams.find_by(territory: membership_data['territory_name'], mascot: membership_data['team_name'])
          else
            league.teams.find_by(mascot: membership_data['team_name'])
          end
          
          if team.nil?
            SeedHelpers.log_and_puts "Warning: Team not found: #{membership_data['team_name']}"
            next
          end
          
          conference = membership_data['conference_name'] ? league.conferences.find_by(name: membership_data['conference_name']) : nil
          if membership_data['conference_name'] && conference.nil?
            SeedHelpers.log_and_puts "Warning: Conference not found: #{membership_data['conference_name']}"
            next
          end
          
          division = membership_data['division_name'] ? league.divisions.find_by(name: membership_data['division_name'], conference: conference) : nil
          if membership_data['division_name'] && division.nil?
            SeedHelpers.log_and_puts "Warning: Division not found: #{membership_data['division_name']}"
            next
          end
          
          # Deactivate any existing active memberships for this team if this one is active
          if membership_data['active']
            Membership.where(team: team, active: true).update_all(active: false)
          end
          
          # Prepare attributes
          attributes = membership_data.except('team_name', 'territory_name', 'conference_name', 'division_name')
          attributes['team'] = team
          attributes['league'] = league
          attributes['conference'] = conference
          attributes['division'] = division
          
          # Parse date fields
          if attributes['start_year'] && !attributes['start_year'].nil?
            attributes['start_date'] = Date.new(attributes['start_year'], 1, 1)
          end
          attributes.delete('start_year')
          
          if attributes['end_year'] && !attributes['end_year'].nil?
            attributes['end_date'] = Date.new(attributes['end_year'], 12, 31)
          end
          attributes.delete('end_year')
          
          SeedHelpers.find_or_create_with_changes(
            Membership,
            { team: team, league: league, conference: conference, division: division, start_date: attributes['start_date'] },
            attributes.except('team', 'league', 'conference', 'division', 'start_date')
          )
        end
      end
    end
    
    SeedHelpers.log_and_puts "Memberships seeding complete: #{Membership.count} total"
  end
end
