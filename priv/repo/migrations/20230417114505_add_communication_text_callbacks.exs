defmodule Central.Repo.Migrations.AddCommunicationTextCallbacks do
  use Ecto.Migration

  def change do
    create table(:communication_text_callbacks) do
      add :name, :string
      add :triggers, {:array, :string}

      add :response, :text

      add :rules, :jsonb
    end
  end
end
