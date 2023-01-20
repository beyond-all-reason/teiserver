defmodule Teiserver.Protocols.Spring.BattleOut do
  alias Teiserver.Account
  alias Teiserver.Battle.Lobby

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  def do_reply(_, _, %{userid: nil}), do: ""
  def do_reply(:lobby_rename, lobby_id, _state) do
    case Lobby.get_lobby(lobby_id) do
      nil ->
        ""
      lobby ->
        "s.battle.update_lobby_title #{lobby_id}\t#{lobby.name}\n"
    end
  end

  def do_reply(:queue_status, {nil, _}, _), do: ""
  def do_reply(:queue_status, {lobby_id, id_list}, %{userid: userid}) do
    case Account.get_client_by_id(userid) do
      %{app_status: :accepted} ->
        if Enum.empty?(id_list) do
          "s.battle.queue_status #{lobby_id}\n"
        else
          name_list = id_list
            |> Enum.map(&Account.get_username_by_id/1)
            |> Enum.reject(&(&1 == nil))
            |> Enum.join("\t")

          "s.battle.queue_status #{lobby_id}\t#{name_list}\n"
        end

      _ ->
        ""
    end
  end
end
