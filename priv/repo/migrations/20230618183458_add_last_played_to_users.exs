defmodule Teiserver.Repo.Migrations.AddLastPlayedToUsers do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :last_played, :utc_datetime
      add :last_logout, :utc_datetime
    end
  end
end
