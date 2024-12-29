defmodule Teiserver.Repo.Migrations.AddMicroblogPosterAlias do
  use Ecto.Migration

  def change do
    alter table("microblog_posts") do
      add :poster_alias, :string
    end
  end
end
