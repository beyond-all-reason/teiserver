defmodule Central.Repo.Migrations.AddAccountRatingsTable do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_ratings, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :rating_type_id, references(:teiserver_game_rating_types, on_delete: :nothing), primary_key: true

      add :rating_value, :float
      add :skill, :float
      add :uncertainty, :float
    end
    create index(:teiserver_account_ratings, [:user_id])
  end
end
