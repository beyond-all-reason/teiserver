defmodule Teiserver.Autohost.Types.Overview do
  @moduledoc """
  Meant to be held in the registry for autohosts. To be used to find appropriate
  autohost when starting a battle.
  """

  alias Teiserver.Bot.Bot

  @enforce_keys [:id, :max_battles, :current_battles]
  defstruct [:id, :max_battles, :current_battles]

  @type t() :: %__MODULE__{
          id: Bot.id(),
          max_battles: non_neg_integer(),
          current_battles: non_neg_integer()
        }
end
