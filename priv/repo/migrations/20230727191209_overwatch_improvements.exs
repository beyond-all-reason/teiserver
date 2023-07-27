defmodule Teiserver.Repo.Migrations.OverwatchImprovements do
  use Ecto.Migration

  def change do
    create table(:moderation_report_groups) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)

      add :action_id, references(:moderation_actions, on_delete: :nothing)

      timestamps()
    end

    create index(:moderation_report_group, [:user_id])

    create table(:moderation_report_group_votes, primary_key: false) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing), primary_key: true
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :action, :string
      add :accurate, :string

      timestamps()
    end

    create table(:moderation_report_group_messages) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :content, :text

      timestamps()
    end

    alter table(:moderation_actions) do
      add :appeal_status, :string, default: nil
    end

    create table(:moderation_appeals_messages) do
      add :action_id, references(:moderation_actions, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :content, :text

      timestamps()
    end
  end
end
