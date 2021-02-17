defmodule Central.Repo.Migrations.CreateConfigUser do
  use Ecto.Migration

  def change do
    create table(:config_user) do
      add :key, :string
      add :value, :string
      add :user_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end

    create index(:config_user, [:user_id])
  end
end
