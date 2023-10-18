defmodule Teiserver.Repo.Migrations.AddLastTriggeredTimeToTextCallbacks do
  use Ecto.Migration

  def change do
    alter table(:communication_text_callbacks) do
      add :last_triggered, :jsonb
    end
  end
end
