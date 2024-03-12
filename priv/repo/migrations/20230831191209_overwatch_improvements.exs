defmodule Barserver.Repo.Migrations.OverwatchImprovements do
  use Ecto.Migration

  def change do
    create table(:moderation_report_groups) do
      add :target_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)

      add :action_count, :integer
      add :report_count, :integer
      add :vote_count, :integer

      add :closed, :boolean

      timestamps()
    end

    create index(:moderation_report_groups, [:target_id])

    alter table(:moderation_reports) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
    end

    create table(:moderation_report_group_votes, primary_key: false) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing),
        primary_key: true

      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :action, :string
      add :accuracy, :string

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
      add :discord_message_id, :bigint, default: nil
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
    end

    create table(:moderation_appeals_messages) do
      add :action_id, references(:moderation_actions, on_delete: :nothing)
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :content, :text

      timestamps()
    end

    alter table(:direct_messages) do
      add :delivered, :boolean, default: false
    end

    alter table(:account_relationships) do
      add :ignore, :boolean, default: false
    end

    execute "UPDATE account_relationships SET ignore = true WHERE state IN ('ignore', 'block', 'avoid');"
    execute "UPDATE account_relationships SET state = null WHERE state = 'ignore';"
  end
end
