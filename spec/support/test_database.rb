# Specs that turn off transactional tests commit their records. They empty
# the tables afterwards with TestDatabase.truncate.
module TestDatabase
  def self.truncate
    connection = ActiveRecord::Base.connection
    connection.truncate_tables(*(connection.tables - [ ActiveRecord::Base.schema_migrations_table_name, ActiveRecord::Base.internal_metadata_table_name ]))
  end
end
