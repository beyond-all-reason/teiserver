defmodule Teiserver.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:account_users) do
      add :name, :string
      add :email, :string
      add :password, :string

      add :icon, :string
      add :colour, :string

      add :permissions, {:array, :string}
      add :data, :jsonb

      add :trust_score, :integer
      add :behaviour_score, :integer
      add :social_score, :integer, default: 0

      add :roles, {:array, :string}
      add :last_login, :utc_datetime
      add :last_played, :utc_datetime
      add :last_logout, :utc_datetime

      add :restrictions, {:array, :string}, default: []
      add :restricted_until, :utc_datetime

      add :shadowbanned, :boolean, default: false

      add :discord_id, :integer
      add :steam_id, :integer

      add :smurf_of_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end

    # alter table(:account_users) do
    #   add :smurf_of_id, references(:account_users, on_delete: :nothing)
    # end

    create index(:account_users, [:name])
    create unique_index(:account_users, [:email])

    create table(:teiserver_account_user_stats, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :data, :jsonb
    end
  end
end
