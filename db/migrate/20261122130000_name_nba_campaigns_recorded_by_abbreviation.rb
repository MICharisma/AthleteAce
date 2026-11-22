# The 2023-24 and 2024-25 NBA Campaigns were seeded with Basketball Reference
# abbreviations ("OKC") as their display names, and seed replay preserves
# existing values. This replaces only names that are still abbreviations with
# the names ESPN's season standings list, as the seed library now records.
class NameNbaCampaignsRecordedByAbbreviation < ActiveRecord::Migration[8.1]
  SEASONS = %w[2023_2024 2024_2025].freeze
  NAMES = {
    "ATL" => "Atlanta Hawks", "BKN" => "Brooklyn Nets", "BOS" => "Boston Celtics", "CHA" => "Charlotte Hornets",
    "CHI" => "Chicago Bulls", "CLE" => "Cleveland Cavaliers", "DAL" => "Dallas Mavericks", "DEN" => "Denver Nuggets",
    "DET" => "Detroit Pistons", "GSW" => "Golden State Warriors", "HOU" => "Houston Rockets", "IND" => "Indiana Pacers",
    "LAC" => "LA Clippers", "LAL" => "Los Angeles Lakers", "MEM" => "Memphis Grizzlies", "MIA" => "Miami Heat",
    "MIL" => "Milwaukee Bucks", "MIN" => "Minnesota Timberwolves", "NOP" => "New Orleans Pelicans", "NYK" => "New York Knicks",
    "OKC" => "Oklahoma City Thunder", "ORL" => "Orlando Magic", "PHI" => "Philadelphia 76ers", "PHX" => "Phoenix Suns",
    "POR" => "Portland Trail Blazers", "SAC" => "Sacramento Kings", "SAS" => "San Antonio Spurs", "TOR" => "Toronto Raptors",
    "UTA" => "Utah Jazz", "WAS" => "Washington Wizards"
  }.freeze

  def up
    SEASONS.product(NAMES.to_a).each do |season, (team, name)|
      execute <<~SQL
        UPDATE campaigns SET display_name = #{quote name}, updated_at = CURRENT_TIMESTAMP
        WHERE entity_code = #{quote "BKT-NBA-SEASON_#{season}-TEAM-#{team}"} AND display_name ~ '^[A-Z]{2,4}$'
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The abbreviations were never names"
  end

  private

  def quote(value)
    connection.quote value
  end
end
