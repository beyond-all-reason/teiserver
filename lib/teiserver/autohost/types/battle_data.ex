defmodule Teiserver.Autohost.Types.BattleData do
  @moduledoc """
  Whatever is required to track the state of a battle being run by a given
  autohost.
  Part of the autohost session state.
  """

  alias Teiserver.Autohost.Types, as: AT

  @enforce_keys [:start_script, :ips, :port]
  defstruct [:start_script, :ips, :port, pending_acks: :queue.new(), last_acked_ts: nil]

  @type t() :: %__MODULE__{
          start_script: AT.StartScript.t(),
          ips: [String.t()],
          port: non_neg_integer(),
          # it is guaranteed that the event timestamp is unique per battle
          pending_acks: :queue.queue(time: DateTime.t()),
          last_acked_ts: DateTime.t() | nil
        }
end
