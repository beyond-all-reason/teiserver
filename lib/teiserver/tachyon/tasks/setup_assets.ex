defmodule Teiserver.Tachyon.Tasks.SetupAssets do
  @moduledoc """
  Seed the database with game and engine version so that matchmaking
  works out of the box.
  Does nothing if there are already assets setup.
  """
  alias Teiserver.Asset
  alias Teiserver.Repo

  def ensure_engine() do
    case Asset.get_engines() do
      [] -> create_engine()
      engines -> update_engine(engines)
    end
  end

  defp create_engine() do
    # the engine version can be found by running `spring -version`
    case Asset.create_engine(%{name: "2025.01.6", in_matchmaking: true}) do
      {:ok, engine} -> {:ok, {:created, engine}}
      {:error, changeset} -> {:error, {:create, changeset}}
    end
  end

  defp update_engine([first_engine | _] = engines) do
    case Enum.find(engines, fn g -> g.in_matchmaking end) do
      nil ->
        result =
          Asset.change_engine(first_engine, %{in_matchmaking: true})
          |> Repo.update()

        case result do
          {:ok, engine} -> {:ok, {:updated, engine}}
          {:error, err} -> {:error, {:update, err}}
        end

      engine ->
        {:ok, {:noop, engine}}
    end
  end

  def ensure_game() do
    case Asset.get_games() do
      [] -> create_game()
      games -> update_game(games)
    end
  end

  defp create_game() do
    # the latest version can be found with
    # curl -Ls https://repos-cdn.beyondallreason.dev/byar/versions.gz | zcat | grep byar:test | cut -d, -f 4
    case Asset.create_game(%{name: "Beyond All Reason test-26929-d709d32", in_matchmaking: true}) do
      {:ok, game} -> {:ok, {:created, game}}
      {:error, changeset} -> {:error, {:create, changeset}}
    end
  end

  defp update_game([first_game | _] = games) do
    case Enum.find(games, fn g -> g.in_matchmaking end) do
      nil ->
        result =
          Asset.change_game(first_game, %{in_matchmaking: true})
          |> Repo.update()

        case result do
          {:ok, game} -> {:ok, {:updated, game}}
          {:error, err} -> {:error, {:update, err}}
        end

      game ->
        {:ok, {:noop, game}}
    end
  end
end
