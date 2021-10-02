defmodule Central.Repo.Migrations.BanHashes do
  use Ecto.Migration

  def change do
    create table(:teiserver_ban_hashes) do
      add :type, :string
      add :value, :string

      add :added_by_id, references(:account_users, on_delete: :nothing)

      # The user we're basing it on
      add :user_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end
  end
end
