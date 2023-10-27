defmodule Teiserver.Protocols.Spring.UserOut do
  @moduledoc false
  require Logger

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  def do_reply(_, _, %{userid: nil}), do: ""

  def do_reply(:list_relationships, data, _state) do
    encoded_data =
      data
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.list_relationships #{encoded_data}\n"
  end

  def do_reply(:closeness, {username, closeness}, _state) do
    "s.user.closeness userName=#{username}\t#{closeness}\n"
  end

  def do_reply(:add_friend, result_list, _state) do
    result_list
    |> Enum.map_join("", fn
      {id, :success} -> "s.user.add_friend #{id}\tsuccess\n"
      {id, :no_user} -> "s.user.add_friend #{id}\tfailure\tno user of that id\n"
      {id, :existing} -> "s.user.add_friend #{id}\tfailure\texisting friend request\n"
      {id, reason} -> "s.user.add_friend #{id}\tfailure\tno failure catch for #{reason}\n"
    end)
  end

  def do_reply(:whois_name, {:no_user, username}, _state) do
    "s.user.whoisName error: No user found for name:#{username}\n"
  end

  def do_reply(:whois_name, {:ok, user}, _state) do
    encoded_data = user
      |> Map.take(~w(id name country icon colour)a)
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.whoisName #{user.name} #{encoded_data}\n"
  end

  def do_reply(:whois, {:no_user, userid}, _state) do
    "s.user.whois error: No user found for id:#{userid}\n"
  end

  def do_reply(:whois, {:ok, user}, _state) do
    encoded_data = user
      |> Map.take(~w(name country icon colour)a)
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.whois #{user.id} #{encoded_data}\n"
  end

  # From pubsubs
  def do_reply(:new_incoming_friend_request, %{from_id: from_id}, _state) do
    "s.user.new_incoming_friend_request #{from_id}\n"
  end

  def do_reply(:friend_request_accepted, %{accepter_id: accepter_id}, _state) do
    "s.user.friend_request_accepted #{accepter_id}\n"
  end

  def do_reply(:friend_request_declined, %{decliner_id: decliner_id}, _state) do
    "s.user.friend_request_declined #{decliner_id}\n"
  end

  def do_reply(:friend_request_rescinded, %{rescinder_id: rescinder_id}, _state) do
    "s.user.friend_request_rescinded #{rescinder_id}\n"
  end

  def do_reply(:new_follower, %{follower_id: follower_id}, _state) do
    "s.user.new_follower #{follower_id}\n"
  end

  def do_reply(event, msg, _state) do
    Logger.error("No handler for event `#{event}` with msg #{inspect msg}")
    "\n"
  end
end
