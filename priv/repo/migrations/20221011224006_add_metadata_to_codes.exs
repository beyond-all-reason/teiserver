defmodule Central.Repo.Migrations.AddMetadataToCodes do
  use Ecto.Migration

  def change do
    alter table(:account_codes) do
      add :metadata, :jsonb
    end
  end
end
