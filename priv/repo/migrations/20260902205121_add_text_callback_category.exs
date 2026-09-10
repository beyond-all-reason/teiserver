defmodule Teiserver.Repo.Migrations.AddTextCallbackCategory do
  use Ecto.Migration

  def change do
    alter table(:communication_text_callbacks) do
      add :category, :text, default: "default", null: false
      remove :triggers
    end
  end
end
