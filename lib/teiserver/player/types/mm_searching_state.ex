defmodule Teiserver.Player.Types.MmSearchingState do
  @moduledoc """
  When the player is looking for matchmaking, currently queueing
  """

  alias Teiserver.Matchmaking

  @enforce_keys [:joined_queues]
  defstruct [:joined_queues]

  @type t :: %__MODULE__{
          joined_queues: nonempty_list(Matchmaking.queue_id())
        }
end
