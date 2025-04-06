defmodule Teiserver.Repo.Migrations.AddTotalMatches do
  use Ecto.Migration

  def change do
    alter table("teiserver_account_ratings") do
      add :total_matches, :integer, default: 0
      add :total_wins, :integer, default: 0
    end
  end
end
