defmodule Teiserver.Repo.Migrations.BadgesAndAccolades do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_badge_types) do
      add :name, :string
      add :icon, :string
      add :colour, :string
      add :description, :text

      add :purposes, {:array, :string}

      timestamps()
    end

    create table(:teiserver_account_accolades) do
      add :recipient_id, references(:account_users, on_delete: :nothing)
      add :giver_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing), null: true

      add :badge_type_id, references(:teiserver_account_badge_types, on_delete: :nothing),
        null: true

      add :inserted_at, :utc_datetime
    end

    create index(:teiserver_account_accolades, [:match_id])
    create index(:teiserver_account_accolades, [:recipient_id])
    create index(:teiserver_account_accolades, [:giver_id])
    create index(:teiserver_account_accolades, [:badge_type_id])
  end
end
