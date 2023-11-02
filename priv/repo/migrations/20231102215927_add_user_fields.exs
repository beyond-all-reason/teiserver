defmodule Teiserver.Repo.Migrations.AddUserFields do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :discord_dm_channel_id, :bigint
      add :last_login_timex, :utc_datetime
    end
  end
end
