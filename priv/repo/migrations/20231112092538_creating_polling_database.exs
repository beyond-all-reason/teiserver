defmodule Teiserver.Repo.Migrations.CreatingPollingDatabase do
  use Ecto.Migration

  def change do
    create table(:polling_surveys) do
      add :name, :string, null: false
      add :author_id, references(:account_users, on_delete: :nothing), null: false

      add :colour, :string
      add :icon, :string

      add :opens_at, :utc_datetime
      add :closes_at, :utc_datetime
      add :questions_last_updated_at, :utc_datetime
      add :is_open, :boolean

      add :user_permission, :string
      add :results_permission, :string
      add :edit_permission, :string

      timestamps()
    end
    create unique_index(:polling_surveys, [:name])

    create table(:polling_questions) do
      add :label, :string, null: false
      add :description, :string
      add :question_type, :string, null: false

      add :options, :jsonb
      add :ordering, :integer, null: false
      add :page, :integer, null: false

      add :survey_id, references(:polling_surveys, on_delete: :nothing)

      timestamps()
    end
    create unique_index(:polling_questions, [:survey_id])


    create table(:polling_responses) do
      add :survey_id, references(:polling_surveys, on_delete: :nothing)
      add :responder_id, references(:account_users, on_delete: :nothing)

      add :is_completed, :boolean, default: false, null: false
      add :completed_at, :utc_datetime

      add :current_page, :integer

      timestamps()
    end
    create index(:polling_responses, [:survey_id])

    create table(:polling_answer_strings, primary_key: false) do
      add :response_id, references(:polling_responses, on_delete: :nothing), primary_key: true
      add :question_id, references(:polling_questions, on_delete: :nothing), primary_key: true

      add :value, :string
    end
    create index(:polling_answer_strings, [:response_id])
    create index(:polling_answer_strings, [:question_id])

    create table(:polling_answer_lists, primary_key: false) do
      add :response_id, references(:polling_responses, on_delete: :nothing), primary_key: true
      add :question_id, references(:polling_questions, on_delete: :nothing), primary_key: true

      add :value, {:array, :string}
    end
    create index(:polling_answer_lists, [:response_id])
    create index(:polling_answer_lists, [:question_id])
  end
end
