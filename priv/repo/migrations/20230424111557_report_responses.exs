defmodule Central.Repo.Migrations.ReportResponses do
  use Ecto.Migration

  def change do
    create table(:moderation_report_responses) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :target_id, references(:moderation_reports, on_delete: :nothing)

      add :mute_actionable, :boolean, default: false
      add :mute_actionable, :boolean, default: false
      add :accurate, :boolean, default: false

      timestamps()
    end

    alter table(:moderation_reports) do
      add :primary_response_id, references(:moderation_reports, on_delete: :nothing)
    end
  end
end
