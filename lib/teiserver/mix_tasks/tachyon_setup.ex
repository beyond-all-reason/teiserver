defmodule Mix.Tasks.Teiserver.TachyonSetup do
  @usage_str "Usage: `mix teiserver.tachyon_setup`"

  @moduledoc """
  Ensure there is an OAuth app for tachyon lobby and another one to control
  assets like maps and engines with bots.

  #{@usage_str}
  """

  @shortdoc "setup oauth apps for tachyon"

  use Mix.Task
  alias Teiserver.Tachyon.Tasks.{SetupApps, SetupAssets}

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started([:ecto, :ecto_sql, :tzdata])
    Teiserver.Repo.start_link()
    SetupApps.ensure_lobby_app()
    SetupApps.ensure_asset_admin_app()
    SetupApps.ensure_user_admin_app()

    case SetupAssets.ensure_engine() do
      {:ok, {:created, engine}} ->
        Mix.shell().info("Engine created with name #{engine.name}")

      {:ok, {:updated, engine}} ->
        Mix.shell().info("Engine with name #{engine.name} set up for matchmaking")

      {:ok, {:noop, _}} ->
        Mix.shell().info("Engine already setup for matchmaking")
    end

    case SetupAssets.ensure_game() do
      {:ok, {:created, game}} ->
        Mix.shell().info("game created with name #{game.name}")

      {:ok, {:updated, game}} ->
        Mix.shell().info("game with name #{game.name} set up for matchmaking")

      {:ok, {:noop, _}} ->
        Mix.shell().info("game already setup for matchmaking")
    end

    case SetupAssets.ensure_maps() do
      {:ok, {:updated, %{deleted_count: deleted, created_count: created}}} ->
        Mix.shell().info("Updated maps: deleted #{deleted}, created #{created}")

      {:error, {:update, reason, _changeset}} ->
        Mix.shell().error("Failed to update maps: #{reason}")
    end
  end
end
