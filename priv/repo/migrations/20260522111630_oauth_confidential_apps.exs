defmodule Teiserver.Repo.Migrations.OauthConfidentialApps do
  use Ecto.Migration

  def change do
    alter table(:oauth_applications) do
      add :secret, :text, null: true, default: nil
    end
  end
end
