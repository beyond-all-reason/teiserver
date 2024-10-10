defmodule Teiserver.Repo.Migrations.RemoveAccountUsersScores do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :trust_score, :integer
      remove :behaviour_score, :integer
      remove :social_score
    end
  end
end
