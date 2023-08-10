defmodule Teiserver.Account.FriendRequestLib do
  @moduledoc false
  alias Teiserver.Account
  alias Account.FriendRequest
  alias Teiserver.Data.Types, as: T

  @spec colours :: atom
  def colours(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-user-plus"

  # Functions
  @spec accept_friend_request(T.userid, T.userid) :: :ok | {:error, String.t()}
  def accept_friend_request(from_id, to_id) do
    case Account.get_friend_request(from_id, to_id) do
      nil ->
        {:error, "no request"}
      req ->
        accept_friend_request(req)
    end
  end

  @spec accept_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  def accept_friend_request(%FriendRequest{} = req) do
    case Account.get_friend(req.from_user_id, req.to_user_id) do
      nil ->
        {:ok, _friend} = Account.create_friend(req.from_user_id, req.to_user_id)
        Account.delete_friend_request(req)
        :ok

      _ ->
        Account.delete_friend_request(req)
        :ok
    end
  end

  @spec decline_friend_request(T.userid, T.userid) :: :ok | {:error, String.t()}
  def decline_friend_request(from_id, to_id) do
    case Account.get_friend_request(from_id, to_id) do
      nil ->
        {:error, "no request"}
      req ->
        decline_friend_request(req)
    end
  end

  @spec decline_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  def decline_friend_request(%FriendRequest{} = req) do
    Account.delete_friend_request(req)
    :ok
  end

  @doc """
  The same as declining for now but intended to be used where the person declining
  is the sender
  """
  @spec rescind_friend_request(T.userid, T.userid) :: :ok | {:error, String.t()}
  def rescind_friend_request(from_id, to_id) do
    case Account.get_friend_request(from_id, to_id) do
      nil ->
        {:error, "no request"}
      req ->
        rescind_friend_request(req)
    end
  end

  @spec rescind_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  def rescind_friend_request(%FriendRequest{} = req) do
    Account.delete_friend_request(req)
    :ok
  end

  @spec list_incoming_friend_requests_of_userid(T.userid) :: [T.userid]
  def list_incoming_friend_requests_of_userid(userid) do
    Central.cache_get_or_store(:account_incoming_friend_request_cache, userid, fn ->
      Account.list_friend_requests(
        where: [
          to_user_id: userid
        ],
        select: [:from_user_id]
      )
        |> Enum.map(fn %{from_user_id: from_user_id} ->
          from_user_id
        end)
    end)
  end
end
