defmodule Teiserver.TachyonLobby.Types.ListState do
  @moduledoc """
  Internal state for the processes holding list of lobbies
  """

  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Types, as: LT

  defstruct monitors: MC.new(),
            counter: 0,
            lobbies: %{},
            changes: %{}

  @type t() :: %__MODULE__{
          monitors: MC.t(),
          counter: non_neg_integer(),
          lobbies: %{LT.Types.id() => LT.ListOverview.t()},
          # the map is a partial overview
          changes: %{LT.Types.id() => map()}
        }
end
