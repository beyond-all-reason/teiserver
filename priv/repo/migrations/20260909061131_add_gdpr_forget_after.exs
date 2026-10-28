defmodule Teiserver.Repo.Migrations.AddGdprForgetAfter do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :gdpr_forget_after, :timestamp, nullable: true
    end
  end
end
