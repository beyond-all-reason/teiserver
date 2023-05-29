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
    end
  end
end
