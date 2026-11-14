# Figure claims start pending and become public only through an admin's
# explicit publication of their current revision (AA-217).
class AddReviewStateToFigureClaims < ActiveRecord::Migration[8.1]
  TABLES = %i[figure_business_relationships figure_practice_relationships attributed_statements].freeze

  def change
    TABLES.each do |table|
      add_column table, :moderation_status, :string, null: false, default: "pending"
      add_column table, :moderation_revision, :integer, null: false, default: 1
      add_column table, :revision_transaction, :string
      add_index table, :moderation_status
      add_check_constraint table, "moderation_status IN ('pending', 'approved', 'rejected', 'hidden')",
        name: "#{table}_moderation_status"
    end
  end
end
