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

    create_if_not_exists table(:oauth_codes, comment: "authorisation codes") do
      add :value, :string, null: false
      add :owner_id, references(:account_users, on_delete: :delete_all), null: false
      add :application_id, references(:oauth_applications, on_delete: :delete_all), null: false
      add :scopes, {:array, :string}, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end
    create_if_not_exists unique_index(:oauth_codes, [:value])

  end
end
