defmodule Teiserver.Coordinator.Parser do
  @moduledoc false
  alias Teiserver.Account.User
  alias Teiserver.Battle
  alias Teiserver.Coordinator

  @passthrough ~w(explain)

  @spec handle_in(User.id(), String.t(), Types.lobby_id()) :: :say | :handled
  def handle_in(userid, msg, lobby_id) do
    lobby = Battle.get_lobby(lobby_id)

    cond do
      # This instantly catches "saying" commands and means we don't need
      # to parse them
      String.slice(msg, 0..1) == "$ " ->
        :say

      String.slice(msg, 0..0) == "$" and String.length(msg) > 1 ->
        cmd_name =
          msg |> String.replace("$", "") |> String.downcase() |> String.split(" ") |> hd()

        if Enum.member?(@passthrough, cmd_name) do
          :say
        else
          parse_and_handle(userid, msg, lobby)
        end

      true ->
        :say
    end
  end

  @spec parse_and_handle(User.id(), String.t(), map()) :: :handled
  defp parse_and_handle(_userid, _msg, nil), do: :handled

  defp parse_and_handle(userid, msg, battle) do
    cmd = parse_command(userid, msg)
    Coordinator.cast_consul(battle.id, cmd)
    :handled
  end

  @spec parse_command(User.id(), String.t()) :: map()
  def parse_command(userid, string) do
    %{
      raw: string,
      remaining: string,
      silent: false,
      command: nil,
      error: nil,
      senderid: userid
    }
    |> parse_silence()
    |> parse_command_name()
  end

  defp parse_silence(%{remaining: remaining} = cmd) do
    case String.slice(remaining, 0..1) == "$%" do
      true ->
        %{cmd | silent: true, remaining: "$" <> String.slice(remaining, 2, 2048)}

      false ->
        cmd
    end
  end

  @spec parse_command_name(map()) :: map()
  defp parse_command_name(%{remaining: string} = cmd) do
    case Regex.run(~r/\$([a-zA-Z0-9\-\?]+) ?/, string) do
      [_full, command_name] ->
        %{
          cmd
          | command: String.downcase(command_name),
            remaining: String.slice(string, String.length(command_name) + 2, 999)
        }

      _no_match ->
        cmd
    end
  end
end
