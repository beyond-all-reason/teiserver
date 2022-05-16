defmodule Teiserver.Protocols.Tachyon.V1.UserIn do
  alias Teiserver.{Account, User, Client}
  alias Teiserver.Protocols.Tachyon.V1.Tachyon
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle("list_users_from_ids", %{"id_list" => id_list} = args, state) do
    users = id_list
      |> User.list_users
      |> Enum.filter(fn u -> u != nil end)
      |> Enum.map(fn u ->
        stats = Account.get_user_stat_data(u.id)
        updated_u = Map.merge(u, %{
          country: stats["country"],
          icons: %{
            "play_time_rank" => stats["rank"]
          }
        })

        Tachyon.convert_object(:user, updated_u)
      end)

    if Map.get(args, "include_clients", false) do
      clients = id_list
        |> Client.list_clients()
        |> Enum.filter(fn c -> c != nil end)
        |> Enum.map(fn c -> Tachyon.convert_object(:client, c) end)

      reply(:user, :user_and_client_list, {users, clients}, state)
    else
      reply(:user, :user_list, users, state)
    end
  end

  def do_handle("list_friend_ids", _, state) do
    friend_list = User.get_user_by_id(state.userid).friends
    reply(:user, :friend_id_list, friend_list, state)
  end

  def do_handle(cmd, data, state) do
    reply(:system, :error, %{location: "auth.handle", error: "No match for cmd: '#{cmd}' with data '#{Kernel.inspect data}'"}, state)
  end
end
