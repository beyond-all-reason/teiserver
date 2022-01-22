defmodule Teiserver.Protocols.Spring.BattleIn do
  alias Teiserver.Battle.Lobby
  alias Teiserver.{Coordinator, User}
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("update_lobby_title", new_name, msg_id, state) do
    if Lobby.allow?(state.userid, :update_lobby, state.lobby_id) do
      Lobby.rename_lobby(state.lobby_id, new_name)
      reply(:spring, :okay, "c.battle.update_lobby_title", msg_id, state)
    end

    state
  end

  def do_handle("update_host", json_str, _msg_id, state) do
    case Jason.decode(json_str) do
      {:ok, data} ->
        host_data = %{
          host_boss: User.get_userid(data["boss"]),
          host_teamsize: data["teamSize"] |> int_parse,
          host_teamcount: data["nbTeams"] |> int_parse
        }
        Coordinator.cast_consul(state.lobby_id, {:host_update, state.userid, host_data})
      v ->
        Logger.error("update_spads instruction error #{Kernel.inspect v}, tried to decode #{json_str}")
    end
    state
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.battle." <> cmd, msg_id, data)
  end
end
