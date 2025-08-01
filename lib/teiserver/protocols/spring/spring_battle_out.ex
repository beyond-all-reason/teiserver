defmodule Teiserver.Protocols.Spring.BattleOut do
  alias Teiserver.Account
  alias Teiserver.Lobby

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

  def do_reply(:summary, {nil, _}, _), do: ""
  def do_reply(:summary, {_, {nil, _}}, _), do: ""
  def do_reply(:summary, {_, {_, nil}}, _), do: ""

  def do_reply(:summary, {_lobby_id, _data}, %{app_status: :accepted}) do
    # Placeholder for summary command we plan to add later
    ""
  end

  def do_reply(:summary, _, _state), do: ""

  def do_reply(:queue_status, nil, _), do: ""
  def do_reply(:queue_status, {nil, _}, _), do: ""
  def do_reply(:queue_status, {_, nil}, _), do: ""

  def do_reply(:queue_status, {lobby_id, id_list}, %{app_status: :accepted}) do
    if Enum.empty?(id_list) do
      "s.battle.queue_status #{lobby_id}\n"
    else
      name_list =
        id_list
        |> Enum.map(&Account.get_username_by_id/1)
        |> Enum.reject(&(&1 == nil))
        |> Enum.join("\t")

      "s.battle.queue_status #{lobby_id}\t#{name_list}\n"
    end
  end

  def do_reply(:queue_status, _, _state), do: ""

  def do_reply(:extra_data, nil, _), do: ""
  def do_reply(:extra_data, {nil, _}, _), do: ""
  def do_reply(:extra_data, {_, nil}, _), do: ""

  def do_reply(:extra_data, {lobby_id, raw_data}, %{app_status: :accepted}) do
    encoded_data =
      raw_data
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.battle.extra_data #{lobby_id}\t#{encoded_data}\n"
  end

  def do_reply(:extra_data, _, _state), do: ""

  def do_reply(:battle_teams, data, _state) do
    encoded_data =
      data
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.battle.teams #{encoded_data}\n"
  end
end
