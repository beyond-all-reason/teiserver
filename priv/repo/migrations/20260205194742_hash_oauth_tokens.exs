defmodule Teiserver.Repo.Migrations.HashOauthTokens do
  use Ecto.Migration

  def up do
    alter table(:oauth_tokens) do
      add :selector, :string, null: false
      add :hashed_verifier, :string, null: false
    end

    alter table(:oauth_codes) do
      add :selector, :string, null: false
      add :hashed_verifier, :string, null: false
    end

    drop_if_exists index(:oauth_tokens, [:value])
    drop_if_exists index(:oauth_codes, [:value])

    alter table(:oauth_tokens) do
      remove :value
    end

    alter table(:oauth_codes) do
      remove :value
    end

    create unique_index(:oauth_tokens, [:selector])
    create unique_index(:oauth_codes, [:selector])
  end

  def down do
    drop_if_exists index(:oauth_tokens, [:selector])
    drop_if_exists index(:oauth_codes, [:selector])

    alter table(:oauth_tokens) do
      add :value, :string
      remove :selector
      remove :hashed_verifier
    end

    alter table(:oauth_codes) do
      add :value, :string
      remove :selector
      remove :hashed_verifier
    end

    create unique_index(:oauth_tokens, [:value])
    create unique_index(:oauth_codes, [:value])
  end
end
