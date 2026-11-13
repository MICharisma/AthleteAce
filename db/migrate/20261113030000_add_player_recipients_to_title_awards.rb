# A title can go to a team's entry (a championship), to a person (a drivers'
# championship, an MVP), or to a person representing an entry (Finals MVP
# for the Nuggets). The winner entry becomes optional; a title needs at least
# one recipient.
class AddPlayerRecipientsToTitleAwards < ActiveRecord::Migration[8.1]
  def change
    add_reference :title_awards, :player, foreign_key: true
    change_column_null :title_awards, :winner_id, true
    add_check_constraint :title_awards, "winner_id IS NOT NULL OR player_id IS NOT NULL", name: "title_awards_have_a_recipient"
  end
end
