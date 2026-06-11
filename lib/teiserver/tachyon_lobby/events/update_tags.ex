defmodule Teiserver.TachyonLobby.Events.UpdateTags do
  @moduledoc """
  To change the tags for a lobby
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:changes]
  defstruct [:changes]

  @type t() :: %__MODULE__{
          changes: %{String.t() => map() | nil}
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateTags do
  alias Teiserver.Helpers.Collections
  alias Teiserver.TachyonLobby.Events.UpdateTags
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateTags{} = ev, %LT.Aggregate{} = agg) do
    data = %{agg.data | tags: Collections.patch_merge(agg.data.tags, ev.changes)}
    changes = Map.put(agg.changes, :tags, ev.changes)
    %{agg | data: data, changes: changes}
  end
end
