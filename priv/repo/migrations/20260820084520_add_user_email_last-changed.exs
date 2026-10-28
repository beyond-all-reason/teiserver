defmodule Teiserver.Repo.Migrations.AddUserEmailLastChanged do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :email_last_changed_at, :timestamp, nullable: true
      add :previous_emails, {:array, :string}, nullable: true
    end
  end
end
