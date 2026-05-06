defmodule Teiserver.Repo.Migrations.RemoveAchievements do
  use Ecto.Migration

  def up do
    drop table(:teiserver_user_achievements)
    drop table(:teiserver_achievement_types)
  end

  def down do
    raise "Cannot revert removal of achievements"
  end
end
