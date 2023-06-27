defmodule Teiserver.Repo.Migrations.AutomatedModerationCreation do
  use Ecto.Migration

  def change do
    create table(:moderation_actions) do
      add :target_id, references(:account_users, on_delete: :nothing)
      add :reason, :text
      add :restrictions, :jsonb
      add :score_modifier, :integer
      add :expires, :naive_datetime

      timestamps()
    end

    create index(:moderation_actions, [:target_id])

    create table(:moderation_reports) do
      add :reporter_id, references(:account_users, on_delete: :nothing)
      add :target_id, references(:account_users, on_delete: :nothing)

      add :type, :string
      add :sub_type, :string
      add :extra_text, :string

      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
      add :relationship, :string
      add :result_id, references(:moderation_actions, on_delete: :nothing)

      timestamps()
    end

    create index(:moderation_reports, [:reporter_id])
    create index(:moderation_reports, [:target_id])

    create table(:moderation_proposals) do
      add :proposer_id, references(:account_users, on_delete: :nothing)
      add :target_id, references(:account_users, on_delete: :nothing)
      add :action_id, references(:moderation_actions, on_delete: :nothing)

      add :restrictions, :jsonb
      add :reason, :text
      add :duration, :string

      add :votes_for, :integer, default: 0
      add :votes_against, :integer, default: 0
      add :votes_abstain, :integer, default: 0

      add :concluder_id, references(:account_users, on_delete: :nothing)
      add :conclusion_comments, :text

      timestamps()
    end

    create index(:moderation_proposals, [:target_id])

    create table(:moderation_proposal_votes, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :proposal_id, references(:moderation_proposals, on_delete: :nothing, primary_key: true)
      add :vote, :smallint

      timestamps()
    end

    create index(:moderation_proposal_votes, [:proposal_id])

    create table(:moderation_bans) do
      add :source_id, references(:account_users, on_delete: :nothing)
      add :added_by_id, references(:account_users, on_delete: :nothing)

      add :key_values, :jsonb
      add :enabled, :boolean
      add :reason, :text

      timestamps()
    end

    alter table(:account_users) do
      add :trust_score, :integer
      add :behaviour_score, :integer
    end
  end
end
