defmodule Central.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:account_users) do
      add :name, :string
      add :email, :string
      add :password, :string

      add :icon, :string
      add :colour, :string

      add :permissions, {:array, :string}
      add :data, :jsonb

      timestamps()
    end

    create unique_index(:account_users, [:email])
  end
end
