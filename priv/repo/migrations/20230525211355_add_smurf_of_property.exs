defmodule Central.Repo.Migrations.AddSmurfOfProperty do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :smurf_of_id, references(:account_users, on_delete: :nothing)
    end
  end
end
