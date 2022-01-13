defmodule Teiserver.Protocols.Spring.BattleOut do
  alias Teiserver.Battle.Lobby

  @spec do_reply(atom(), nil | String.t() | tuple() | list()) :: String.t()
  def do_reply(:lobby_rename, lobby_id) do
    case Lobby.get_lobby(lobby_id) do
      nil ->
        ""
      lobby ->
        "s.battle.update_lobby_title #{lobby_id}\t#{lobby.name}\n"
    end
  end
end
