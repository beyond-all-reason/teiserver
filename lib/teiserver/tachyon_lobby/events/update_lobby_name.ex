defmodule Teiserver.TachyonLobby.Events.UpdateLobbyName do
  @moduledoc """
  To change the name of the lobby
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:new_name]
  defstruct [:new_name]

  @type t() :: %__MODULE__{
          new_name: String.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateLobbyName do
  alias Teiserver.TachyonLobby.Events.UpdateLobbyName
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateLobbyName{} = ev, %LT.Aggregate{} = agg) do
    data = Map.put(agg.data, :name, ev.new_name)
    changes = Map.put(agg.changes, :name, ev.new_name)
    overview_changes = Map.put(agg.overview_changes, :name, ev.new_name)
    %{agg | data: data, changes: changes, overview_changes: overview_changes}
  end
end
