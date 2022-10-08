defmodule Teiserver.Protocols.Tachyon.V1.UserOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:user_list, {users, clients}) do
    %{
      cmd: "s.user.user_list",
      users: users,
      clients: clients
    }
  end

  def do_reply(:user_list, users) do
    %{
      cmd: "s.user.user_list",
      users: users
    }
  end

  def do_reply(:list_friend_ids, {friend_ids, request_ids}) do
    %{
      cmd: "s.user.list_friend_ids",
      friend_id_list: friend_ids,
      request_id_list: request_ids
    }
  end

  def do_reply(:list_friend_users_and_clients, {users, clients}) do
    %{
      cmd: "s.user.list_friend_users_and_clients",
      user_list: users,
      client_list: clients
    }
  end

  def do_reply(:friend_added, friend_id) do
    %{
      cmd: "s.user.friend_added",
      user_id: friend_id
    }
  end

  def do_reply(:friend_removed, friend_id) do
    %{
      cmd: "s.user.friend_removed",
      user_id: friend_id
    }
  end

  def do_reply(:friend_request, requester_id) do
    %{
      cmd: "s.user.friend_request",
      user_id: requester_id
    }
  end
end
