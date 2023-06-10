defmodule Central.Repo.Migrations.AddNotesToActions do
  use Ecto.Migration

  def change do
    alter table(:moderation_actions) do
      add :notes, :text
    end
  end
end
