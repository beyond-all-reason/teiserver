defmodule Teiserver.Repo.Migrations.InfologSize do
  use Ecto.Migration

  def change do
    alter table(:teiserver_telemetry_infologs) do
      add :size, :integer
    end
  end
end
