defmodule Teiserver.Protocols.Tachyon.V1.UserOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:user_list, users) do
    %{
      cmd: "s.user.user_list",
      users: users
    }
  end

  def do_reply(:friend_id_list, id_list) do
    %{
      cmd: "s.user.list_friend_ids",
      friend_id_list: id_list
    }
  end
end
