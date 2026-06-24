defmodule Teiserver.Autohost.Types.SessionData do
  @moduledoc """
  Data/state held by the process associated with a connected autohost
  """

  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Bot.Bot
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonBattle

  @enforce_keys [:autohost, :conn_pid]
  defstruct [
    :autohost,
    :conn_pid,
    monitors: MC.new(),
    max_battles: 0,
    current_battles: 0,
    pending_battles: %{},
    active_battles: %{},
    pending_replies: %{}
  ]

  @type t() :: %__MODULE__{
          autohost: Bot.t(),
          conn_pid: pid(),
          monitors: MC.t(),
          max_battles: non_neg_integer(),
          current_battles: non_neg_integer(),
          pending_battles: %{TachyonBattle.id() => {GenServer.from(), AT.StartScript.t()}},
          active_battles: %{TachyonBattle.id() => AT.BattleData.t()},
          pending_replies: %{reference() => GenServer.from()}
        }
end
