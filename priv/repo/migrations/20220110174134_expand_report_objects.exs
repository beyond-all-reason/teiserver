defmodule Central.Repo.Migrations.ExpandReportObjects do
  use Ecto.Migration

  def change do
    alter table(:account_reports) do
      add :followup, :string
      add :responded_at, :utc_datetime
      add :code_references, {:array, :string}
    end
  end
end
