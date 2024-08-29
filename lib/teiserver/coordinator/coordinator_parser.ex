defmodule Teiserver.Coordinator.Parser do
  require Logger
  alias Teiserver.Coordinator
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Battle

  @passthrough ~w(explain)

  @spec handle_in(Types.userid(), String.t(), Types.lobby_id()) :: :say | :handled
  def handle_in(userid, msg, lobby_id) do
    lobby = Battle.get_lobby(lobby_id)

    cond do
      # This instantly catches "saying" commands and means we don't need
      # to parse them
      String.slice(msg, 0..1) == "$ " ->
        :say

      String.slice(msg, 0..0) == "$" and String.length(msg) > 1 ->
        cmd_name = msg |> String.replace("$", "") |> String.downcase() |> String.split(" ") |> hd

        if Enum.member?(@passthrough, cmd_name) do
          :say
        else
          parse_and_handle(userid, msg, lobby)
        end

      true ->
        :say
    end
  end

  @spec parse_and_handle(Types.userid(), String.t(), map()) :: :handled
  defp parse_and_handle(_, _, nil), do: :handled

  defp parse_and_handle(userid, msg, battle) do
    cmd = parse_command(userid, msg)
    Coordinator.cast_consul(battle.id, cmd)
    :handled
  end

  @spec parse_command(T.userid(), String.t()) :: map()
  def parse_command(userid, string) do
    %{
      raw: string,
      remaining: string,
      silent: false,
      command: nil,
      error: nil,
      senderid: userid
    }
    |> parse_silence
    |> parse_command_name
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
    case Regex.run(~r/\$([a-z0-9\-\?]+) ?/, string) do
      [_, command_name] ->
        %{
          cmd
          | command: command_name,
            remaining: String.slice(string, String.length(command_name) + 2, 999)
        }

      _ ->
        cmd
    end
  end
end
