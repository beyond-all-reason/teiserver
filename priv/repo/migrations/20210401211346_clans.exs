defmodule Teiserver.Repo.Migrations.Clans do
  use Ecto.Migration

  def change do
    create table(:teiserver_clans) do
      add :name, :string
      add :tag, :string
      add :icon, :string
      add :colour1, :string
      add :colour2, :string
      add :text_colour, :string

      add :description, :text
      add :rating, :jsonb
      add :homepage, :jsonb

      timestamps()
    end

    create index(:teiserver_clans, [:name])
    create index(:teiserver_clans, [:tag])

    create table(:teiserver_clan_memberships, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :clan_id, references(:teiserver_clans, on_delete: :nothing), primary_key: true
      add :role, :string

      timestamps()
    end

    create table(:teiserver_clan_invites, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :clan_id, references(:teiserver_clans, on_delete: :nothing), primary_key: true
      add :response, :string

      timestamps()
    end

    alter table(:account_users) do
      add :clan_id, references(:teiserver_clans, on_delete: :nothing)
    end
  end
end
