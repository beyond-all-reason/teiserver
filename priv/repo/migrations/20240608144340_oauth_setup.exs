defmodule Teiserver.Repo.Migrations.OauthSetup do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:oauth_applications) do
      add :name, :string, null: false, comment: "display name"
      add :owner_id, references(:account_users, on_delete: :delete_all)
      add :uid, :string, null: false, comment: "aka client_id"
      add :scopes, {:array, :string}, null: false
      add :redirect_uris, {:array, :string}, null: false, default: []
      add :description, :text

      timestamps(type: :utc_datetime)
    end
    create_if_not_exists unique_index(:oauth_applications, [:uid])
  end
end
