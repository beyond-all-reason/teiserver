defmodule Teiserver.Protocols.Tachyon.V1.UserIn do
  alias Teiserver.{Account, User, Client}
  alias Teiserver.Protocols.Tachyon.V1.Tachyon
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Data.Types, as: T

  @spec do_handle(String.t(), Map.t(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle("list_users_from_ids", %{"id_list" => id_list} = args, state) do
    users =
      id_list
      |> User.list_users()
      |> Enum.filter(fn u -> u != nil end)
      |> Enum.map(fn u ->
        stats = Account.get_user_stat_data(u.id)

        updated_u =
          Map.merge(u, %{
            country: stats["country"],
            icons: %{
              "play_time_rank" => stats["rank"]
            }
          })

        Tachyon.convert_object(updated_u, :user)
      end)

    if Map.get(args, "include_clients", true) do
      clients =
        id_list
        |> Client.list_clients()
        |> Enum.filter(fn c -> c != nil end)
        |> Enum.map(fn c -> Tachyon.convert_object(c, :client) end)

      reply(:user, :user_list, {users, clients}, state)
    else
      reply(:user, :user_list, users, state)
    end
  end

  def do_handle("list_friend_ids", _, state) do
    user = User.get_user_by_id(state.userid)
    friend_list = user.friends
    request_list = user.friend_requests

    reply(:user, :list_friend_ids, {friend_list, request_list}, state)
  end

  def do_handle("list_friend_users_and_clients", _, state) do
    friend_list = User.get_user_by_id(state.userid).friends

    users =
      friend_list
      |> Account.list_users_from_cache()
      |> Enum.reject(&(&1 == nil))
      |> Tachyon.convert_object(:user)

    clients =
      friend_list
      |> Account.list_clients()
      |> Enum.reject(&(&1 == nil))
      |> Tachyon.convert_object(:client_friend)

    reply(:user, :list_friend_users_and_clients, {users, clients}, state)
  end

  def do_handle("add_friend", %{"user_id" => user_id}, state) when is_integer(user_id) do
    User.create_friend_request(state.userid, user_id)
    state
  end

  def do_handle("rescind_friend_request", %{"user_id" => user_id}, state)
      when is_integer(user_id) do
    User.rescind_friend_request(state.userid, user_id)
    state
  end

  def do_handle("accept_friend_request", %{"user_id" => user_id}, state)
      when is_integer(user_id) do
    User.accept_friend_request(user_id, state.userid)
    state
  end

  def do_handle("reject_friend_request", %{"user_id" => user_id}, state)
      when is_integer(user_id) do
    User.decline_friend_request(user_id, state.userid)
    state
  end

  def do_handle("remove_friend", %{"user_id" => user_id}, state) when is_integer(user_id) do
    User.remove_friend(state.userid, user_id)
    state
  end

  def do_handle(cmd, data, state) do
    reply(
      :system,
      :error,
      %{
        location: "auth.handle",
        error: "No match for cmd: '#{cmd}' with data '#{Kernel.inspect(data)}'"
      },
      state
    )
  end
end
