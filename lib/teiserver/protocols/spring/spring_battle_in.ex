defmodule Teiserver.Protocols.Spring.BattleIn do
  alias Teiserver.Battle.Lobby
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("update_lobby_title", new_name, msg_id, state) do
    if Lobby.allow?(state.userid, :update_lobby, state.lobby_id) do
      Lobby.rename_lobby(state.lobby_id, new_name)
      reply(:spring, :okay, "c.battle.update_lobby_title", msg_id, state)
    end

    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.matchmaking." <> cmd, msg_id, data)
  end
end
