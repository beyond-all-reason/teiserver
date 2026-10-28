defmodule Teiserver.TachyonLobby.Events.UpdateMapName do
  @moduledoc """
  To change the tags for a lobby
  """

  alias Teiserver.Asset
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:new_map]
  defstruct [:new_map, :polygon_startboxes]

  @type t() :: %__MODULE__{
          new_map: String.t(),
          polygon_startboxes: Asset.polystartbox_modoptions() | nil
        }

  @spec new(String.t()) :: t()
  def new(new_map_name) do
    %__MODULE__{
      new_map: new_map_name,
      polygon_startboxes: Asset.get_polygon_startboxes(new_map_name)
    }
  end
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateMapName do
  alias Teiserver.TachyonLobby.Events.UpdateGameOptions
  alias Teiserver.TachyonLobby.Events.UpdateMapName
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateMapName{} = ev, %LT.Aggregate{} = agg) do
    data = %{agg.data | map_name: ev.new_map}
    changes = Map.put(agg.changes, :map_name, ev.new_map)
    overview_changes = Map.put(agg.overview_changes, :map_name, ev.new_map)
    new_agg = %{agg | data: data, changes: changes, overview_changes: overview_changes}

    case ev.polygon_startboxes do
      nil ->
        new_agg

      polygon_modoptions ->
        Teiserver.TachyonLobby.Event.apply_event(
          %UpdateGameOptions{
            changes: polygon_modoptions
          },
          new_agg
        )
    end
  end
end
