defmodule Teiserver.Repo.Migrations.CreateUserNotes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_notes, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :user_id, references(:account_users, on_delete: :nothing), null: false
      add :contents, :text

      add :creator_id, references(:account_users, on_delete: :nothing), null: false
      add :permission, :text

      timestamps()
    end
  end
end
