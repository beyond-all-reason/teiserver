defmodule Teiserver.Account.FriendRequestLib do
  @moduledoc false
  alias Teiserver.Account
  alias Account.FriendRequest
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  @spec colours :: atom
  def colours(), do: :success

  @spec icon :: String.t()
  def icon(), do: "fa-user-question"

  @spec can_send_friend_request?(T.userid(), T.userid()) :: boolean
  def can_send_friend_request?(from_id, to_id) do
    {result, _} = can_send_friend_request_with_reason?(from_id, to_id)
    result
  end

  @spec can_send_friend_request_with_reason?(T.userid(), T.userid()) ::
          {true, :ok} | {false, String.t()}
  def can_send_friend_request_with_reason?(from_id, to_id) do
    cond do
      from_id == nil ->
        {false, "nil from_id"}

      to_id == nil ->
        {false, "nil to_id"}

      from_id == to_id ->
        {false, "Cannot add yourself as a friend"}

      Account.get_friend(from_id, to_id) != nil ->
        {false, "Already friends"}

      # Check for existing outgoing request (from current user to target)
      # Note: We don't check for incoming requests here because they should trigger auto-accept
      Account.get_friend_request(from_id, to_id) != nil ->
        {false, "Existing request"}

      Account.does_a_ignore_b?(to_id, from_id) ->
        {false, "Ignored"}

      Account.does_a_avoid_b?(to_id, from_id) ->
        {false, "Avoided"}

      true ->
        {true, :ok}
    end
  end

  # Functions
  @spec accept_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
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

        PubSub.broadcast(
          Teiserver.PubSub,
          "account_user_relationships:#{req.from_user_id}",
          %{
            channel: "account_user_relationships:#{req.from_user_id}",
            event: :friend_request_accepted,
            userid: req.from_user_id,
            accepter_id: req.to_user_id
          }
        )

        :ok

      _ ->
        Account.delete_friend_request(req)
        :ok
    end
  end

  @spec decline_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
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

    PubSub.broadcast(
      Teiserver.PubSub,
      "account_user_relationships:#{req.from_user_id}",
      %{
        channel: "account_user_relationships:#{req.from_user_id}",
        event: :friend_request_declined,
        userid: req.from_user_id,
        decliner_id: req.to_user_id
      }
    )

    :ok
  end

  @doc """
  The same as declining for now but intended to be used where the person declining
  is the sender
  """
  @spec rescind_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
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

    PubSub.broadcast(
      Teiserver.PubSub,
      "account_user_relationships:#{req.to_user_id}",
      %{
        channel: "account_user_relationships:#{req.to_user_id}",
        event: :friend_request_rescinded,
        userid: req.to_user_id,
        rescinder_id: req.from_user_id
      }
    )

    :ok
  end

  @doc """
  Returns all friend requests for the given user
  """
  @spec list_requests_for_user(T.userid()) :: {outgoing :: [map()], incoming :: [map()]}
  def list_requests_for_user(userid) do
    Account.list_friend_requests(where: [to_or_from_is: userid])
    |> Enum.reduce({[], []}, fn req, {outgoing, incoming} ->
      if req.from_user_id == userid do
        {[req | outgoing], incoming}
      else
        {outgoing, [req | incoming]}
      end
    end)
  end

  @spec list_incoming_friend_requests_of_userid(T.userid()) :: [T.userid()]
  def list_incoming_friend_requests_of_userid(userid) do
    {_, incoming} = list_requests_for_user(userid)
    Enum.map(incoming, fn incoming -> incoming.from_user_id end)
  end

  @spec list_outgoing_friend_requests_of_userid(T.userid()) :: [T.userid()]
  def list_outgoing_friend_requests_of_userid(userid) do
    {outgoing, _} = list_requests_for_user(userid)
    Enum.map(outgoing, fn outgoing -> outgoing.to_user_id end)
  end
end
