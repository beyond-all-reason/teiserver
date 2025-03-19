defmodule Teiserver.Repo.Migrations.SeasonAsPrimaryKey do
  use Ecto.Migration

  def change do
    execute("""
    ALTER TABLE teiserver_account_ratings DROP CONSTRAINT teiserver_account_ratings_pkey;
    """)

    execute("""
    ALTER TABLE teiserver_account_ratings ADD PRIMARY KEY (user_id, rating_type_id, season);
    """)
  end
end
