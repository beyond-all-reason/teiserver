defmodule Central.Repo.Migrations.CreateBlog do
  use Ecto.Migration

  def change do
    create table(:communication_categories) do
      add :name, :string
      add :colour, :string
      add :icon, :string

      add :public, :boolean, default: false, null: false

      timestamps()
    end

    create index(:communication_categories, [:name])

    create table(:communication_posts) do
      add :url_slug, :string
      add :title, :string
      add :content, :text
      add :short_content, :text
      add :live_from, :utc_datetime

      add :tags, {:array, :string}

      add :allow_comments, :boolean, default: false, null: false
      add :visible, :boolean, default: false, null: false

      add :category_id, references(:communication_categories, on_delete: :nothing)
      add :poster_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:communication_posts, [:url_slug])
    create index(:communication_posts, [:category_id])
    create index(:communication_posts, [:poster_id])

    create table(:communication_comments) do
      add :content, :text

      add :approved, :boolean, default: false, null: false
      add :ip, :string

      add :post_id, references(:communication_posts, on_delete: :nothing)
      add :poster_id, references(:account_users, on_delete: :nothing)
      add :poster_name, :string

      timestamps()
    end

    create index(:communication_comments, [:post_id])
    create index(:communication_comments, [:poster_id])

    create table(:communication_blog_files) do
      add :name, :string
      add :url, :string
      add :file_ext, :string
      add :file_path, :string
      add :file_size, :integer

      timestamps()
    end

    create unique_index(:communication_blog_files, [:url])
  end
end
