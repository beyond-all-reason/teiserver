defmodule Teiserver.Repo.Migrations.RemoveCallbackIconAndColour do
  use Ecto.Migration

  def change do
    alter table(:communication_text_callbacks) do
      remove :colour
      remove :icon
    end
  end
end
