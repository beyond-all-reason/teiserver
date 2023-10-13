defmodule Teiserver.Repo.Migrations.MicroblogDiscord do
  use Ecto.Migration

  def change do
    create table(:communication_discord_channels) do
      add :name, :string
      add :channel_id, :bigint

      add :view_permission, :string
      add :post_permission, :string

      add :colour, :string
      add :icon, :string

      timestamps()
    end
    create unique_index(:communication_discord_channels, [:name])

    alter table(:microblog_posts) do
      add :discord_channel_id, references(:communication_discord_channels, on_delete: :nothing)
      add :discord_post_id, :bigint
    end
  end
end
