defmodule Teiserver.TachyonLobby.Events.RemoveBot do
  @moduledoc """
  Removing a bot from the lobby
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:bot_id]
  defstruct [:bot_id]

  @type t() :: %__MODULE__{
          bot_id: LT.Bot.id()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.RemoveBot do
  alias Teiserver.TachyonLobby.Event
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.RemoveBot
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%RemoveBot{} = ev, %LT.Aggregate{} = agg) do
    Enum.reduce(
      [
        %Events.RemovePlayerFromLobby{player_id: ev.bot_id},
        %Events.RepackPlayers{},
        %Events.FillFromJoinQueue{}
      ],
      agg,
      &Event.apply_event/2
    )
  end
end
