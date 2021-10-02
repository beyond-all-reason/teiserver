defmodule Central.Repo.Migrations.SiteConfig do
  use Ecto.Migration

  def change do
    create table(:config_site, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :string

      timestamps()
    end
  end
end
