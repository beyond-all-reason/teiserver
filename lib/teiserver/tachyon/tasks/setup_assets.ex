defmodule Teiserver.Tachyon.Tasks.SetupAssets do
  @moduledoc """
  Seed the database with game, engine, and map assets so that matchmaking
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

  def ensure_maps do
    maps_data = load_maps_from_json()

    case Asset.update_maps(maps_data) do
      {:ok, stats} -> {:ok, {:updated, stats}}
      {:error, reason} -> {:error, {:update, reason, nil}}
    end
  end

  defp load_maps_from_json do
    json_path = Path.join([Application.app_dir(:teiserver), "priv", "data", "maps.json"])
    content = File.read!(json_path)
    %{"maps" => maps} = Jason.decode!(content)

    maps
    |> Enum.map(&transform_map_data/1)
    |> Enum.reject(&is_nil/1)
  end

  defp transform_map_data(map_json) do
    %{
      "spring_name" => map_json["springName"],
      "display_name" => map_json["displayName"],
      "matchmaking_queues" => map_json["matchmakingQueues"] || [],
      "thumbnail_url" => map_json["thumbnail"],
      "startboxes_set" => map_json["startboxesSet"] || [],
      "modoptions" => map_json["modoptions"] || %{}
    }
  end
end
