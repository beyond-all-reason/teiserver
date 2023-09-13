defmodule Teiserver.Repo.Migrations.AddSocialScore do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :social_score, :integer, default: 0
    end
  end
end
