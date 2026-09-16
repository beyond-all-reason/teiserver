defmodule Teiserver.Repo.Migrations.RemoveTextCallbackRules do
  use Ecto.Migration

  def change do
    alter table(:communication_text_callbacks) do
      remove :rules
    end
  end
end
