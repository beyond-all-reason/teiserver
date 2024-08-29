defmodule Teiserver.Protocols.Spring.BattleIn do
  alias Teiserver.{Coordinator, Battle, Lobby}
  alias Teiserver.Protocols.SpringIn
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("update_lobby_title", new_name, msg_id, state) do
    if Lobby.allow?(state.userid, :update_lobby_title, state.lobby_id) do
      Battle.rename_lobby(state.lobby_id, new_name, nil)
      reply(:spring, :okay, "c.battle.update_lobby_title", msg_id, state)
    else
      state
    end
  end

  def do_handle("update_host", json_str, _msg_id, state) do
    case Jason.decode(json_str) do
      {:ok, data} ->
        host_data = %{
          # host_bosses: [User.get_userid(data["boss"])],
          host_teamsize: data["teamSize"] |> int_parse,
          host_teamcount: data["nbTeams"] |> int_parse
        }

        Coordinator.cast_consul(state.lobby_id, {:host_update, state.userid, host_data})

      v ->
        Logger.error(
          "update_spads instruction error #{Kernel.inspect(v)}, tried to decode #{json_str}"
        )
    end

    state
  end

  def do_handle("queue_status", _, _msg_id, %{lobby_id: nil} = state), do: state

  def do_handle("queue_status", _, _msg_id, %{lobby_id: lobby_id, app_status: :accepted} = state) do
    id_list = Coordinator.call_consul(lobby_id, :queue_state)
    reply(:battle, :queue_status, {lobby_id, id_list}, nil, state)
  end

  def do_handle("queue_status", _, _msg_id, state), do: state

  def do_handle("extra_data", _, _msg_id, %{lobby_id: nil} = state), do: state

  def do_handle("extra_data", _, _msg_id, %{lobby_id: lobby_id, app_status: :accepted} = state) do
    data = Coordinator.call_consul(lobby_id, :get_chobby_extra_data)
    reply(:battle, :extra_data, {lobby_id, data}, nil, state)
  end

  def do_handle("extra_data", _, _msg_id, state), do: state

  # def do_handle("refresh_lobby", _, _msg_id, %{lobby_id: nil} = state), do: state
  # def do_handle("refresh_lobby", _, _msg_id, %{lobby_id: lobby_id, app_status: :accepted} = state) do

  # end
  # def do_handle("refresh_lobby", _, _msg_id, state), do: state

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.battle." <> cmd, msg_id, data)
  end
end
