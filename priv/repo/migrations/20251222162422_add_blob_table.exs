defmodule Teiserver.Repo.Migrations.AddBlobTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:blob, primary_key: false) do
      add :store, :string, primary_key: true, null: false
      add :key, :string, primary_key: true, null: false
      add :value, :binary, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime, null: false, default: fragment("now()")
    end
  end
end
