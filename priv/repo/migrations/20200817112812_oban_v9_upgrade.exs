defmodule MyApp.Repo.Migrations.UpdateObanJobsToV9 do
  use Ecto.Migration

  defdelegate up, to: Oban.Migrations
  defdelegate down, to: Oban.Migrations
end
