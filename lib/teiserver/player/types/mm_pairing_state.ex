defmodule Teiserver.Player.Types.MmPairingState do
  @moduledoc """
  When the player is paired with others, and waiting for
  everyone to click "ready"
  """

  alias Teiserver.Matchmaking

  @enforce_keys [:paired_queue, :room, :frozen_queues, :readied?]
  defstruct [:paired_queue, :room, :frozen_queues, :readied?]

  @type t :: %__MODULE__{
          paired_queue: {Matchmaking.queue_id(), version :: String.t()},
          room: pid(),
          # a list of the other queues to rejoin in case the pairing fails
          frozen_queues: [{Matchmaking.queue_id(), version :: String.t()}],
          readied?: boolean()
        }
end
