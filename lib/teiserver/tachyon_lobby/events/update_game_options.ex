defmodule Teiserver.TachyonLobby.Events.UpdateGameOptions do
  @moduledoc """
  To change the game options
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:changes]
  defstruct [:changes]

  @type t() :: %__MODULE__{
          changes: %{String.t() => String.t() | nil}
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateGameOptions do
  alias Teiserver.Helpers.Collections
  alias Teiserver.TachyonLobby.Events.UpdateGameOptions
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateGameOptions{} = ev, %LT.Aggregate{} = agg) do
    data = %{agg.data | game_options: Collections.patch_merge(agg.data.game_options, ev.changes)}
    changes = Map.put(agg.changes, :game_options, ev.changes)
    %{agg | data: data, changes: changes}
  end
end
