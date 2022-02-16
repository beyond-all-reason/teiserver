defmodule Teiserver.Protocols.Tachyon.V1.UserOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:friend_list_ids, id_list) do
    %{
      cmd: "s.user.list_friend_ids",
      friend_id_list: id_list
    }
  end
end
