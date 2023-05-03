defmodule Central.Repo.Migrations.ReportResponses do
  use Ecto.Migration

  def change do
    create table(:moderation_responses, primary_key: false) do
      add :report_id, references(:moderation_reports, on_delete: :nothing), primary_key: true
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :action, :string, default: "Ignore"
      add :accurate, :boolean, default: false

      timestamps()
    end

    alter table(:moderation_reports) do
      add :closed, :boolean, default: false
    end
  end
end
