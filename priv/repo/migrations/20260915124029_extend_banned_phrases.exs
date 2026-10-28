defmodule Teiserver.Repo.Migrations.ExtendBannedPhrases do
  use Ecto.Migration

  def up do
    alter table(:banned_phrases) do
      add :use_cases, :jsonb, default: "[]"
      remove :severity
    end

    execute("DROP TYPE phrase_severity_level")
  end

  def down do
    execute("CREATE TYPE phrase_severity_level AS ENUM ('low', 'medium', 'high')")

    alter table(:banned_phrases) do
      remove :use_cases
      add :severity, :phrase_severity_level, default: "medium"
    end
  end
end
