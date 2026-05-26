defmodule Teiserver.Repo.Migrations.AutomatedModerationTooling do
  use Ecto.Migration

  def change do
    create table(:banned_ips) do
      add :cidr, :text

      timestamps()
    end

    create unique_index(:banned_ips, [:cidr])

    create table(:banned_domains) do
      add :domain, :text

      timestamps()
    end

    create unique_index(:banned_domains, [:domain])

    execute(
      "CREATE TYPE phrase_severity_level AS ENUM ('low', 'medium', 'high')",
      "DROP TYPE phrase_severity_level"
    )

    execute(
      "CREATE TYPE phrase_type AS ENUM ('raw', 'fuzzy', 'regex')",
      "DROP TYPE phrase_type"
    )

    create table(:banned_phrases) do
      add :phrase, :text, null: false
      add :score_threshold, :integer, null: false
      add :type, :phrase_type, null: false
      add :severity, :phrase_severity_level, null: false

      timestamps()
    end
  end
end
