defmodule Teiserver.TachyonLobby.Types.Aggregate do
  @moduledoc """
  An aggregate is used when processing lobby events.
  Reducing events from an initial aggregate leads to a new aggregate that holds
  the new state, and maps of changes to be broadcasted to member or a new overview
  for the lobby list.

  Some events may also generate side effects, like an end vote. These are
  represented in the aggregate as well.

  Computing an aggregate must be a pure operation, that is, there must not be
  any side effects. This is to guarantee we can replicate the state
  in other processes without having to deal with duplicate messages.
  In this context, events are data structure that represent changes to a lobby,
  there is no message passing or IO involved.
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:data]
  defstruct [:data, changes: %{}, overview_changes: %{}, side_effects: [], actions: []]

  @type t() :: %__MODULE__{
          data: LT.Data.t(),
          changes: map(),
          overview_changes: map(),
          # TODO refine that with proper structs/types
          side_effects: list(),
          actions: list(:gen_statem.action())
        }
end
