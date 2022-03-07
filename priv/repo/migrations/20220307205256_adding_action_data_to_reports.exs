defmodule Central.Repo.Migrations.AddingActionDataToReports do
  use Ecto.Migration

  def change do
    alter table(:account_reports) do
      add :action_data, :jsonb
    end
  end
end
