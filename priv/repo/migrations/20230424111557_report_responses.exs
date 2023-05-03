defmodule Central.Repo.Migrations.ReportResponses do
  use Ecto.Migration

  def change do
    create table(:moderation_responses) do
      add :report_id, references(:moderation_reports, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :warn, :boolean, default: false
      add :mute, :boolean, default: false
      add :suspend, :boolean, default: false
      add :accurate, :boolean, default: false

      timestamps()
    end

    alter table(:moderation_reports) do
      add :closed, :boolean, default: false
    end
  end
end
