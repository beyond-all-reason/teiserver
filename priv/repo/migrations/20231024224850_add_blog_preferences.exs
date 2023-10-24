defmodule Teiserver.Repo.Migrations.AddBlogPreferences do
  use Ecto.Migration

  def change do
    create table(:microblog_user_preferences, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :enabled_tags, {:array, :integer}
      add :disabled_tags, {:array, :integer}

      add :enabled_posters, {:array, :integer}
      add :disabled_posters, {:array, :integer}

      timestamps()
    end
  end
end
