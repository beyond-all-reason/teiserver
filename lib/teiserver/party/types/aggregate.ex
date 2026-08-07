defmodule Teiserver.Party.Types.Aggregate do
  @moduledoc """
  An aggregate used when processing events related to parties
  """

  alias Teiserver.Party.Types, as: PT

  @enforce_keys [:data]
  defstruct [:data, side_effects: [], actions: []]

  @type t() :: %__MODULE__{
          data: PT.Data.t(),
          side_effects: list(),
          actions: list(:gen_statem.action())
        }
end
