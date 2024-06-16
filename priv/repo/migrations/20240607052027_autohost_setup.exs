defmodule Teiserver.Repo.Migrations.AutohostSetup do
  use Ecto.Migration

  # This migration is really more a placeholder for the "new" autohost table
  # used in tachyon. It'll be extended later as we implement tachyon and
  # figure out what's required here.
  # For now, only the basics so that we can bind oauth client secrets creds
  # to the correct table from the start
  def change do
    create_if_not_exists table(:teiserver_autohosts) do
      add :name, :string, comment: "short name to identify the host"
      timestamps(type: :utc_datetime)
    end
  end
end
