defmodule Teiserver.Player.Types.MmPairingState do
  @moduledoc """
  When the player is paired with others, and waiting for
  everyone to click "ready"
  """

  alias Teiserver.Matchmaking

  @enforce_keys [:paired_queue, :room, :frozen_queues, :readied?, :timeout_at]
  defstruct [:paired_queue, :room, :frozen_queues, :readied?, :timeout_at, battle_password: ""]
  # TODO: remove the battle password from there. It should only be a battle
  # concern, and let the player know about it when joining.

  @type t :: %__MODULE__{
          paired_queue: Matchmaking.queue_ref(),
          room: pid(),
          # a list of the other queues to rejoin in case the pairing fails
          frozen_queues: [Matchmaking.queue_ref()],
          readied?: boolean(),
          timeout_at: DateTime.t(),
          battle_password: String.t()
        }
end
