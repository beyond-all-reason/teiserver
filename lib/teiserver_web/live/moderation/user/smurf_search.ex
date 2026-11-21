defmodule TeiserverWeb.ModerationLive.User.SmurfSearch do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.UserLib
  alias Teiserver.Account.UserQueries
  alias Teiserver.Battle
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  import Teiserver.Logging.Helpers, only: [add_audit_log: 3]

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) when is_connected?(socket) do
    %{scope: scope} = socket.assigns

    user =
      UserQueries.users()
      |> UserQueries.where_id(id)
      |> UserQueries.load_user_stat()
      |> Repo.one()

    if UserLib.can_access_user?(user, scope) do
      user_stats = Account.get_user_stat_data(user.id)

      socket
      |> assign(
        user: user,
        user_stats: user_stats,
        moderator?: allow?(scope, "Moderator")
      )
      |> get_smurf_data()
      |> noreply()
    else
      if user do
        add_audit_log(scope, "User access attempt", %{
          user_id: user && user.id,
          page: "moderation/users/#{user.id}/smurf_search"
        })
      end

      socket
      |> put_flash(:error, "Unable to access this user")
      |> redirect(to: ~p"/moderation/users/#{user.id}/smurf_search")
      |> noreply()
    end
  end

  def handle_params(%{"id" => id}, _url, socket) do
    socket
    |> assign(
      user: nil,
      user_id: id
    )
    |> noreply()
  end

  defp get_smurf_data(%Socket{assigns: assigns} = socket) do
    %{user: user} = assigns

    all_user_keys =
      Account.list_smurf_keys(
        search: [
          user_id: user.id
        ],
        limit: :infinity,
        preload: [:type],
        order_by: "Newest first"
      )

    key_count_by_type_name =
      all_user_keys
      |> Enum.group_by(fn k -> k.type.name end, fn _key -> 1 end)
      |> Enum.map(fn {k, vs} -> {k, Enum.count(vs)} end)
      |> Enum.sort(&<=/2)

    user_key_lookup =
      all_user_keys
      |> Map.new(fn k -> {k.value, k} end)

    matching_keys = Account.smurf_search(user)

    key_types =
      matching_keys
      |> Enum.map(fn {{type, _value}, _matches} -> type end)
      |> Enum.uniq()
      |> Enum.sort()

    users =
      matching_keys
      |> Enum.map(fn {{_type, _value}, matches} ->
        matches
        |> Enum.map(fn m -> m.user end)
      end)
      |> List.flatten()
      |> Map.new(fn user -> {user.id, user} end)
      |> Enum.map(fn {_id, user} -> user end)
      |> Enum.sort_by(
        fn user ->
          user.last_login
        end,
        &>=/2
      )

    # Next we want to know the date of the key we matched against for that user
    key_lookup =
      matching_keys
      |> Enum.map(fn {{matched_type, _matched_value}, matches} ->
        matches
        |> Enum.map(fn match ->
          {{matched_type, match.user_id}, match}
        end)
      end)
      |> List.flatten()
      |> Enum.sort_by(fn {_k, v} -> v.last_updated end, &<=/2)
      |> Map.new()

    stats_map =
      users
      |> Map.new(fn %{id: id} ->
        {id, Account.get_user_stat_data(id)}
      end)

    games_allied =
      users
      |> Map.new(fn %{id: id} ->
        {id,
         Battle.list_matches(
           search: [ally_opponent: {user.id, id, nil}],
           limit: :infinity
         )
         |> length()}
      end)

    games_vs =
      users
      |> Map.new(fn %{id: id} ->
        {id,
         Battle.list_matches(
           search: [ally_opponent: {user.id, nil, id}],
           limit: :infinity
         )
         |> length()}
      end)

    socket
    |> assign(
      key_types: key_types,
      key_count_by_type_name: key_count_by_type_name,
      key_lookup: key_lookup,
      user_key_lookup: user_key_lookup,
      users: users,
      all_user_keys: all_user_keys,
      stats_map: stats_map,
      games_allied: games_allied,
      games_vs: games_vs
    )
  end
end
