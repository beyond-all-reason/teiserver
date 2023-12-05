defmodule Teiserver.Repo.Migrations.CreateMicroblog do
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

    create table(:microblog_tags) do
      add :name, :string
      add :colour, :string
      add :icon, :string

      timestamps()
    end

    create table(:microblog_posts) do
      add :poster_id, references(:account_users, on_delete: :nothing)

      add :title, :string
      add :summary, :text
      add :contents, :text

      add :view_count, :integer
      add :discord_channel_id, references(:communication_discord_channels, on_delete: :nothing)
      add :discord_post_id, :bigint

      timestamps()
    end

    create table(:microblog_post_tags, primary_key: false) do
      add :post_id, references(:microblog_posts, on_delete: :nothing), primary_key: true
      add :tag_id, references(:microblog_tags, on_delete: :nothing), primary_key: true
    end

    create table(:microblog_user_preferences, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :tag_mode, :string

      add :enabled_tags, {:array, :integer}
      add :disabled_tags, {:array, :integer}

      add :enabled_posters, {:array, :integer}
      add :disabled_posters, {:array, :integer}

      timestamps()
    end
  end
end
