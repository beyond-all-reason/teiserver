defmodule Teiserver.Protocols.Tachyon.V1.SystemIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.{Account, Battle}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("ping", cmd, state) do
    reply(:system, :pong, cmd, state)
  end

  def do_handle("watch", %{"channel" => channel}, state) do
    case channel do
      "friends" ->
        user = Account.get_user_by_id(state.userid)

        user.friends
        |> Enum.each(fn f ->
          send(self(), {:action, {:watch_channel, "teiserver_client_watch:#{f}"}})
        end)

        reply(:system, :watch, {:ok, channel}, state)

      "friend:" <> f ->
        f_id = int_parse(f)
        user = Account.get_user_by_id(state.userid)

        if Enum.member?(user.friends, f_id) do
          send(self(), {:action, {:watch_channel, "teiserver_client_watch:#{f}"}})
          reply(:system, :watch, {:ok, channel}, state)
        else
          reply(:system, :watch, {:error, channel, "Not a friend"}, state)
        end

      "server_stats" ->
        send(self(), {:action, {:watch_channel, "teiserver_public_stats"}})
        reply(:system, :watch, {:ok, channel}, state)

      "all_lobbies" ->
        send(self(), {:action, {:watch_channel, "teiserver_global_lobby_updates"}})
        reply(:system, :watch, {:ok, channel}, state)

      "lobby:" <> lobby_id ->
        lobby_id = int_parse(lobby_id)

        case Battle.lobby_exists?(lobby_id) do
          true ->
            send(self(), {:action, {:watch_channel, "teiserver_lobby_updates:#{lobby_id}"}})
            reply(:system, :watch, {:ok, channel}, state)

          false ->
            reply(:lobby, :watch, {:failure, "No lobby", lobby_id}, state)
        end

      _ ->
        reply(:system, :watch, {:failure, channel, "No channel"}, state)
    end
  end

  def do_handle("unwatch", %{"channel" => channel}, state) do
    case channel do
      "friends" ->
        user = Account.get_user_by_id(state.userid)

        user.friends
        |> Enum.each(fn f ->
          send(self(), {:action, {:watch_channel, "teiserver_client_watch:#{f}"}})
        end)

        reply(:system, :unwatch, {:ok, channel}, state)

      "friend:" <> f ->
        send(self(), {:action, {:unwatch_channel, "teiserver_client_watch:#{f}"}})
        reply(:system, :unwatch, {:ok, channel}, state)

      "server_stats" ->
        send(self(), {:action, {:unwatch_channel, "teiserver_public_stats"}})
        reply(:system, :unwatch, {:ok, channel}, state)

      "all_lobbies" ->
        send(self(), {:action, {:unwatch_channel, "teiserver_global_lobby_updates"}})
        reply(:system, :unwatch, {:ok, channel}, state)

      "lobby:" <> lobby_id ->
        send(self(), {:action, {:unwatch_channel, "teiserver_lobby_updates:#{lobby_id}"}})
        reply(:system, :unwatch, {:ok, channel}, state)

      _ ->
        reply(:system, :unwatch, {:failure, channel, "No channel"}, state)
    end
  end
end
