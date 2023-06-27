defmodule Teiserver.Repo.Migrations.AddCommunicationTextCallbacks do
  use Ecto.Migration

  def change do
    create table(:communication_text_callbacks) do
      add :name, :string

      add :icon, :string
      add :colour, :string
      add :enabled, :boolean

      add :triggers, {:array, :string}

      add :response, :text

      add :rules, :jsonb

      timestamps()
    end
  end
end
