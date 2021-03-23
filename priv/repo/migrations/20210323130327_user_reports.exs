defmodule Central.Repo.Migrations.UserReports do
  use Ecto.Migration

  def change do
    create table(:account_reports) do
      add :location, :string
      add :location_id, :integer

      add :reason, :string

      add :response_text, :string
      add :response_action, :string
      add :expires, :naive_datetime

      add :reporter_id, references(:account_users, on_delete: :nothing)
      add :target_id, references(:account_users, on_delete: :nothing)
      add :responder_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end
  end
end
