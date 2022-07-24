defmodule Central.Repo.Migrations.AddSmurfLinkTable do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_smurf_links, primary_key: false) do
      add :user1_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :user2_id, references(:account_users, on_delete: :nothing), primary_key: true

      timestamps()
    end
  end
end
