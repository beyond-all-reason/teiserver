defmodule Teiserver.Asset.MapLib do
  alias Teiserver.Asset
  alias Ecto.Multi
  alias Teiserver.Repo

  @spec create_maps([map()]) ::
          {:ok, [Asset.Map.t()]} | {:error, String.t(), Ecto.Changeset.t(), map()}
  def create_maps(map_attrs) do
    names =
      Enum.with_index(map_attrs)
      |> Enum.map(fn {attr, idx} ->
        name = Map.get(attr, "springName", idx)
        "insert-#{name}"
      end)

    tx =
      Enum.reduce(Enum.zip(map_attrs, names), Multi.new(), fn {attr, name}, multi ->
        Multi.insert(multi, name, Asset.Map.changeset(%Asset.Map{}, attr))
      end)
      |> Repo.transaction()

    case tx do
      {:ok, result_map} -> {:ok, Enum.map(names, fn name -> Map.get(result_map, name) end)}
      err -> err
    end
  end

  @type startbox :: %{top: integer(), bottom: integer(), left: integer(), right: integer()}

  @doc """
  Return the suitable startboxes for the given match and the number of (ally) teams
  nil if nothing matches
  """
  @spec get_startboxes(Asset.Map.t(), number_of_teams :: non_neg_integer()) :: [startbox()] | nil
  def get_startboxes(%Asset.Map{} = map, number_of_teams) do
    # By construction, there's only one startbox definition in the set for a given
    # number of teams:
    # https://github.com/beyond-all-reason/maps-metadata/blob/566a7cd0cb31d3fecd3361190afa69febd1e97d7/scripts/js/src/check_startboxes.ts#L16
    sb =
      Enum.find(map.startboxes_set, fn s ->
        Enum.count(s["startboxes"]) == number_of_teams
      end)

    case sb do
      nil -> nil
      sb -> Enum.map(sb["startboxes"], &poly_to_startbox/1)
    end
  end

  defp poly_to_startbox(startbox) do
    [tl, br] = startbox["poly"]
    # for some ancient unknown reasons, the startboxes range from 0 to 200, but engine
    # wants [0;1], so rescale here
    # originally, the spring protocol defines ADDSTARTRECT for the startboxes
    # these are using [0;200]x[0;200] coordinates
    # The map metadata service is using the same coordinate and this is what's
    # saved in teiserver
    # However, tachyon and engine require the startboxes to be within [0;1] so
    # scale that here. This may not stay this way if/when the map metadata
    # service changes the coordinates
    # https://discord.com/channels/549281623154229250/927564746104905728/1303302250713583727
    %{bottom: br["y"] / 200, left: tl["x"] / 200, top: tl["y"] / 200, right: br["x"] / 200}
  end
end
