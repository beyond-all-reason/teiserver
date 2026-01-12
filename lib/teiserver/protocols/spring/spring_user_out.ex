defmodule Teiserver.Protocols.Spring.UserOut do
  @moduledoc false
  require Logger
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib

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

  def do_reply(:relationship_change, {command, id, :success}, _state) do
    "s.user.#{command} #{id}\tsuccess\n"
  end

  def do_reply(:relationship_change, {command, id, :error}, _state) do
    "s.user.#{command} #{id}\terror\tNo message\n"
  end

  def do_reply(:relationship_change, {command, id, {:error, reason}}, _state) do
    "s.user.#{command} #{id}\terror\t#{reason}\n"
  end

  def do_reply(:add_friend, result_list, _state) do
    result_list
    |> Enum.map_join("", fn
      {id, :success} -> "s.user.add_friend #{id}\tsuccess\n"
      {id, :no_user} -> "s.user.add_friend #{id}\tfailure\tno user of that id\n"
      {id, :existing} -> "s.user.add_friend #{id}\tfailure\texisting friend request\n"
      {id, reason} -> "s.user.add_friend #{id}\tfailure\t#{reason}\n"
    end)
  end

  def do_reply(:remove_friend, result_list, _state) do
    result_list
    |> Enum.map_join("", fn
      {id, :success} -> "s.user.remove_friend #{id}\tsuccess\n"
      {id, :no_user} -> "s.user.remove_friend #{id}\tfailure\tno user of that id\n"
      {id, reason} -> "s.user.remove_friend #{id}\tfailure\tno failure catch for #{reason}\n"
    end)
  end

  def do_reply(:rescind_friend_request, result_list, _state) do
    result_list
    |> Enum.map_join("", fn
      {id, :success} ->
        "s.user.rescind_friend_request #{id}\tsuccess\n"

      {id, :no_user} ->
        "s.user.rescind_friend_request #{id}\tfailure\tno user of that id\n"

      {id, :existing} ->
        "s.user.rescind_friend_request #{id}\tfailure\tno friend request\n"

      {id, reason} ->
        "s.user.rescind_friend_request #{id}\tfailure\tno failure catch for #{reason}\n"
    end)
  end

  def do_reply(:accept_friend_request, {result, from_id_str}, _state) do
    case result do
      {:error, reason} -> "s.user.accept_friend_request #{from_id_str}\tfailure\t#{reason}\n"
      :ok -> "s.user.accept_friend_request #{from_id_str}\tsuccess\n"
      resp -> "s.user.accept_friend_request #{from_id_str}\t#{inspect(resp)}\n"
    end
  end

  def do_reply(:decline_friend_request, {result, from_id_str}, _state) do
    case result do
      {:error, reason} -> "s.user.decline_friend_request #{from_id_str}\tfailure\t#{reason}\n"
      :ok -> "s.user.decline_friend_request #{from_id_str}\tsuccess\n"
      resp -> "s.user.decline_friend_request #{from_id_str}\t#{inspect(resp)}\n"
    end
  end

  def do_reply(:whois_name, {:no_user, username}, _state) do
    encoded_data =
      %{"error" => "user not found"}
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.whoisName #{username} #{encoded_data}\n"
  end

  def do_reply(:whois_name, {:ok, user}, _state) do
    ratings = get_user_ratings(user)

    encoded_data =
      user
      |> Map.take(~w(id name country icon colour)a)
      |> Map.put(:ratings, ratings)
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.whoisName #{user.name} #{encoded_data}\n"
  end

  def do_reply(:whois, {:no_user, userid}, _state) do
    encoded_data =
      %{"error" => "user not found"}
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.whois #{userid} #{encoded_data}\n"
  end

  def do_reply(:whois, {:ok, user}, _state) do
    ratings = get_user_ratings(user)

    encoded_data =
      user
      |> Map.take(~w(name country icon colour)a)
      |> Map.put(:ratings, ratings)
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

  def do_reply(:friend_deleted, %{from_id: from_id}, _state) do
    "s.user.friend_deleted #{from_id}\n"
  end

  def do_reply(event, msg, _state) do
    Logger.error("No handler for event `#{event}` with msg #{inspect(msg)}")
    "\n"
  end

  defp get_user_ratings(user) do
    MatchRatingLib.rating_type_name_lookup()
    |> Enum.map(fn {name, type_id} ->
      case Account.get_rating(user.id, type_id) do
        nil ->
          nil

        rating ->
          {name, %{skill: rating.skill, uncertainty: rating.uncertainty}}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end
end
