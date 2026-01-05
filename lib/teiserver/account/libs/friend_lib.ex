defmodule Teiserver.Account.FriendLib do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Data.Types, as: T

  @spec colours :: atom
  def colours(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-user-group"

  @spec list_friend_ids_of_user(T.userid()) :: [T.userid()]
  def list_friend_ids_of_user(userid) do
    Teiserver.cache_get_or_store(:account_friend_cache, userid, fn ->
      Account.list_friends(
        where: [either_user_is: userid],
        select: ~w(user1_id user2_id)a
      )
      |> Enum.map(fn %{user1_id: u1, user2_id: u2} ->
        if u1 == userid do
          u2
        else
          u1
        end
      end)
    end)
  end
end
