defmodule Teiserver.Repo.Migrations.TrimWebPageLogs do
  use Ecto.Migration

  def change do
    alter table(:aggregate_view_logs) do
      remove :user_data
    end
  end
end
