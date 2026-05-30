defmodule Teiserver.Repo.Migrations.BannedPhraseMatchOptions do
  use Ecto.Migration

  def change do
    alter table(:banned_phrases) do
      add :case_sensitive, :boolean, null: false, default: true
      add :whole_word, :boolean, null: false, default: false
    end
  end
end
