defmodule Central.Repo.Migrations.AutomatedModerationCreation do
  use Ecto.Migration

  def change do
    create table(:moderation_actions) do
      add :target_id, references(:account_users, on_delete: :nothing)
      add :reason, :text
      add :actions, :jsonb
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
      add :result_id, references(:moderation_actions, on_delete: :nothing)

      add :actions, :jsonb
      add :reason, :text
      add :duration, :string

      add :concluded_by_id, references(:account_users, on_delete: :nothing)
      add :conclusion_comments, :text

      timestamps()
    end
    create index(:moderation_proposals, [:target_id])

    create table(:moderation_proposal_votes, primary_key: false) do
      add :voter_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :proposal_id, references(:moderation_proposals, on_delete: :nothing, primary_key: true)
      add :vote, :boolean

      timestamps()
    end
    create index(:moderation_proposal_votes, [:proposal_id])

    create table(:moderation_bans) do
      add :target_id, references(:account_users, on_delete: :nothing)
      add :added_by_id, references(:account_users, on_delete: :nothing)

      add :key_values, :jsonb
      add :enabled, :boolean
      add :reason, :string

      timestamps()
    end

    alter table(:account_users) do
      add :trust_score, :integer
      add :behaviour_score, :integer
    end
  end
end
