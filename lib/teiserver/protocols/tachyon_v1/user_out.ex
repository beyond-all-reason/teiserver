defmodule Teiserver.Protocols.Tachyon.V1.UserOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:user_list, users) do
    %{
      cmd: "s.user.user_list",
      users: users
    }
  end

  def do_reply(:user_and_client_list, {users, clients}) do
    %{
      cmd: "s.user.user_and_client_list",
      users: users,
      clients: clients
    }
  end

  def do_reply(:list_friend_ids, id_list) do
    %{
      cmd: "s.user.list_friend_ids",
      list_friend_ids: id_list
    }
  end

  def do_reply(:list_friend_users_and_clients, {users, clients}) do
    %{
      cmd: "s.user.list_friend_ids",
      user_list: users,
      client_list: clients
    }
  end
end
