defmodule Teiserver.Repo.Migrations.CreateMicroblog do
  use Ecto.Migration

  def change do
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

      timestamps()
    end

    create table(:microblog_post_tags, primary_key: false) do
      add :post_id, references(:microblog_posts, on_delete: :nothing), primary_key: true
      add :tag_id, references(:microblog_tags, on_delete: :nothing), primary_key: true
    end
  end
end
