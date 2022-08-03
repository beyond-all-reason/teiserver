defmodule Central.Repo.Migrations.AddUpdatedAtToSmurfKeys do
  use Ecto.Migration

  def change do
    alter table(:teiserver_account_smurf_keys) do
      add :last_updated, :timestamp
    end

    execute "UPDATE teiserver_account_smurf_keys SET last_updated = '2022-01-01 01:01:01';"
  end
end
