defmodule Teiserver.Matchmaking.Algo.Env do
  @moduledoc """
  An environment passed to the various matchmaking algorithms.
  The state of the algo is something internal, while this represent things
  that may change outside of, like "what time is it".

  This enable the algorithms to be pure functions.
  """

  @enforce_keys [:now]
  defstruct [:now]

  @type t :: %__MODULE__{
          now: DateTime.t()
        }

  @spec default_env() :: t()
  def default_env do
    %__MODULE__{now: DateTime.utc_now()}
  end
end
