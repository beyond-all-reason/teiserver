defmodule Teiserver.Repo.Migrations.AlterClansTable do
  use Ecto.Migration

  def change do
    rename table(:teiserver_clans), :colour1, to: :colour

    alter table(:teiserver_clans) do
      remove :colour2
      remove :text_colour
    end
  end
end
