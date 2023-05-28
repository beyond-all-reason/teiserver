defmodule Central.Repo.Migrations.AddUserFields do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :roles, {:array, :string}
      add :last_login, :utc_datetime

      add :restrictions, {:array, :string}, default: []
      add :restricted_until, :utc_datetime

      add :shadowbanned, :boolean, default: false

      add :discord_id, :integer
      add :steam_id, :integer

      add :last_match_id, references(:teiserver_battle_matches, on_delete: :nothing)
    end
  end
end
