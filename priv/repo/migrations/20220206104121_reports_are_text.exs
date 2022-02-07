defmodule Central.Repo.Migrations.ReportsAreText do
  use Ecto.Migration

  def change do
    alter table(:account_reports) do
      modify :reason, :text
      modify :response_text, :text
      modify :response_action, :text
      modify :followup, :text
    end
  end
end
