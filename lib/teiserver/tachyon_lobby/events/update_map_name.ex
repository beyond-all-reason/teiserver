defmodule Teiserver.TachyonLobby.Events.UpdateMapName do
  @moduledoc """
  To change the tags for a lobby
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:new_map]
  defstruct [:new_map]

  @type t() :: %__MODULE__{
          new_map: String.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateMapName do
  alias Teiserver.TachyonLobby.Events.UpdateMapName
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateMapName{} = ev, %LT.Aggregate{} = agg) do
    data = %{agg.data | map_name: ev.new_map}
    changes = Map.put(agg.changes, :map_name, ev.new_map)
    overview_changes = Map.put(agg.overview_changes, :map_name, ev.new_map)
    %{agg | data: data, changes: changes, overview_changes: overview_changes}
  end
end
