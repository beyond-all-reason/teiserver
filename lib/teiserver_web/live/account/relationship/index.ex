defmodule TeiserverWeb.Account.RelationshipLive.Index do
  @moduledoc false
  alias Teiserver.Account.RelationshipLib
  use TeiserverWeb, :live_view
  alias Teiserver.Account

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:tab, nil)
      |> assign(:site_menu_active, "teiserver_account")
      |> assign(:view_colour, Account.RelationshipLib.colour())
      |> assign(:show_help, false)
      |> put_empty_relationships
      |> assign(:purge_cutoff, get_default_purge_cutoff_option())
      |> assign(:purge_cutoff_options, get_purge_cutoff_options())

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :friend, _params) do
    socket
    |> assign(:page_title, "Relationships - Friends")
    |> assign(:tab, :friend)
    |> put_empty_relationships
    |> get_friends
  end

  defp apply_action(socket, :follow, _params) do
    socket
    |> assign(:page_title, "Relationships - Following")
    |> assign(:tab, :follow)
    |> put_empty_relationships
    |> get_follows
  end

  defp apply_action(socket, :avoid, _params) do
    socket
    |> assign(:page_title, "Relationships - Avoids")
    |> assign(:tab, :avoid)
    |> put_empty_relationships
    |> get_avoids
  end

  defp apply_action(socket, :search, _params) do
    socket
    |> assign(:page_title, "Relationships - Player search")
    |> assign(:tab, :search)
    |> assign(:role_data, Account.RoleLib.role_data())
    |> put_empty_relationships
    |> update_user_search
  end

  defp apply_action(socket, :clean, _params) do
    socket
    |> assign(:page_title, "Relationships - Cleanup")
    |> assign(:tab, :clean)
    |> get_friends()
    |> get_inactive_relationship_count()
  end

  @impl true
  def handle_event("show-help", _, socket) do
    {:noreply, socket |> assign(:show_help, true)}
  end

  def handle_event("hide-help", _, socket) do
    {:noreply, socket |> assign(:show_help, false)}
  end

  def handle_event("search-update", event, %{assigns: %{search_terms: search_terms}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_search = Map.put(search_terms, key, value)

    socket =
      socket
      |> assign(:search_terms, new_search)
      |> update_user_search

    {:noreply, socket}
  end

  def handle_event("accept-friend", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.accept_friend_request(userid, socket.assigns.current_user.id) do
        :ok ->
          socket
          |> put_flash(:success, "Friend request accepted")
          |> get_friends
          |> update_user_search

        {:error, reason} ->
          socket
          |> put_flash(:warning, "There was an error accepting that friend request: '#{reason}'")
          |> get_friends()
      end

    {:noreply, socket}
  end

  def handle_event("decline-friend", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.decline_friend_request(userid, socket.assigns.current_user.id) do
        :ok ->
          socket
          |> put_flash(:success, "Friend request declined")
          |> get_friends
          |> update_user_search

        {:error, reason} ->
          socket
          |> put_flash(:warning, "There was an error declining that friend request: '#{reason}'")
          |> get_friends()
      end

    {:noreply, socket}
  end

  def handle_event("decline-friend-and-block", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.decline_friend_request(userid, socket.assigns.current_user.id) do
        :ok ->
          Account.upsert_relationship(%{
            from_user_id: socket.assigns.current_user.id,
            to_user_id: userid,
            state: "block"
          })

          socket
          |> put_flash(:success, "Friend request declined, user blocked")
          |> get_friends()

        {:error, reason} ->
          socket
          |> put_flash(
            :warning,
            "There was an error declining and blocking that friend request: '#{reason}'"
          )
          |> get_friends()
      end

    {:noreply, socket}
  end

  def handle_event("rescind-friend", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.rescind_friend_request(socket.assigns.current_user.id, userid) do
        :ok ->
          socket
          |> put_flash(:success, "Friend request rescinded")
          |> get_friends
          |> update_user_search

        {:error, reason} ->
          socket
          |> put_flash(:warning, "There was an error rescinding that friend request: '#{reason}'")
          |> get_friends()
      end

    {:noreply, socket}
  end

  def handle_event("unfollow-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    Account.reset_relationship_state(socket.assigns.current_user.id, userid)

    username = Account.get_username_by_id(userid)

    socket =
      socket
      |> put_flash(:success, "#{username} is no longer followed")
      |> get_follows()

    {:noreply, socket}
  end

  def handle_event("unignore-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    Account.unignore_user(socket.assigns.current_user.id, userid)

    username = Account.get_username_by_id(userid)

    socket =
      socket
      |> put_flash(:success, "#{username} is no longer ignored")
      |> get_avoids()

    {:noreply, socket}
  end

  def handle_event("ignore-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.ignore_user(socket.assigns.current_user.id, userid) do
        {:ok, _} ->
          username = Account.get_username_by_id(userid)

          socket
          |> put_flash(:success, "#{username} is now ignored")
          |> get_avoids()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to ignore user: #{reason}")
          |> get_avoids()
      end

    {:noreply, socket}
  end

  def handle_event("unavoid-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    Account.reset_relationship_state(socket.assigns.current_user.id, userid)

    username = Account.get_username_by_id(userid)

    socket =
      socket
      |> put_flash(:success, "#{username} is now avoided")
      |> get_avoids()

    {:noreply, socket}
  end

  def handle_event("avoid-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.avoid_user(socket.assigns.current_user.id, userid) do
        {:ok, _} ->
          username = Account.get_username_by_id(userid)

          socket
          |> put_flash(:success, "#{username} is now avoided")
          |> get_avoids()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to avoid user: #{reason}")
          |> get_avoids()
      end

    {:noreply, socket}
  end

  def handle_event("block-user", %{"userid" => userid_str}, socket) do
    userid = String.to_integer(userid_str)

    socket =
      case Account.block_user(socket.assigns.current_user.id, userid) do
        {:ok, _} ->
          username = Account.get_username_by_id(userid)

          socket
          |> put_flash(:success, "#{username} is now blocked")
          |> get_avoids()

        {:error, reason} ->
          socket
          |> put_flash(:warning, "Failed to block user: #{reason}")
          |> get_avoids()
      end

    {:noreply, socket}
  end

  def handle_event("purge-avoids", _params, socket) do
    userid = socket.assigns.current_user.id
    duration = socket.assigns[:purge_cutoff]
    days = get_purge_days_cutoff(duration)
    num_rows = RelationshipLib.delete_inactive_ignores_avoids_blocks(userid, days)

    socket =
      socket |> assign(:purge_avoids_message, "#{num_rows} inactive users purged.")

    {:noreply, socket}
  end

  def handle_event("purge-friends", _params, socket) do
    duration = socket.assigns[:purge_cutoff]
    days_cutoff = get_purge_days_cutoff(duration)

    # Get all friends of this user
    friends = socket.assigns[:friends]

    num_friends_deleted =
      get_inactive_friends(friends, days_cutoff)
      |> Enum.map(fn friend ->
        Account.delete_friend(friend)
        nil
      end)
      |> length()

    socket =
      socket |> assign(:purge_friends_message, "#{num_friends_deleted} inactive friends purged.")

    {:noreply, socket}
  end

  @doc """
  Handles the dropdown for purge cutoff time
  """
  @impl true
  def handle_event("update-purge-cutoff", event, socket) do
    [key] = event["_target"]
    value = event[key]

    socket =
      socket
      |> assign(:purge_cutoff, value)
      |> get_inactive_relationship_count()
      |> get_inactive_friend_count()

    {:noreply, socket}
  end

  defp update_user_search(
         %{assigns: %{live_action: :search, search_terms: terms} = assigns} = socket
       ) do
    search_term =
      Map.get(terms, "username", "")
      |> String.trim()

    if Enum.member?(["", nil], search_term) do
      socket
    else
      found_user =
        Account.get_user(nil,
          search: [
            name_lower: search_term,
            not_has_role: "Bot"
          ],
          limit: 1
        )

      if found_user do
        relationship = Account.get_relationship(assigns.current_user.id, found_user.id)
        friendship = Account.get_friend(assigns.current_user.id, found_user.id)

        friendship_request =
          Account.get_friend_request(nil, nil,
            where: [either_user_is: {assigns.current_user.id, found_user.id}]
          )

        socket
        |> assign(:found_user, found_user)
        |> assign(:found_relationship, relationship)
        |> assign(:found_friendship, friendship)
        |> assign(:found_friendship_request, friendship_request)
      else
        socket
        |> assign(:found_user, nil)
        |> assign(:found_relationship, nil)
        |> assign(:found_friendship, nil)
        |> assign(:found_friendship_request, nil)
      end
    end
  end

  defp update_user_search(socket) do
    socket
    |> assign(:found_user, nil)
    |> assign(:found_relationship, nil)
    |> assign(:found_friendship, nil)
    |> assign(:found_friendship_request, nil)
  end

  defp put_empty_relationships(socket) do
    socket
    |> assign(:incoming_friend_requests, [])
    |> assign(:outgoing_friend_requests, [])
    |> assign(:friends, [])
    |> assign(:follows, [])
    |> assign(:avoids, [])
    |> assign(:ignores, [])
    |> assign(:blocks, [])
    |> assign(:search_terms, %{"username" => ""})
    |> assign(:found_user, nil)
    |> assign(:found_relationship, nil)
    |> assign(:found_friendship, nil)
    |> assign(:found_friendship_request, nil)
    |> assign(:inactive_friend_count, 0)
  end

  defp get_inactive_relationship_count(
         %{assigns: %{current_user: current_user, purge_cutoff: purge_cutoff}} = socket
       ) do
    user_id = current_user.id
    days = get_purge_days_cutoff(purge_cutoff)

    inactive_relationship_count =
      RelationshipLib.get_inactive_ignores_avoids_blocks_count(user_id, days)

    socket = socket |> assign(:inactive_relationship_count, inactive_relationship_count)
    socket
  end

  defp get_friends(%{assigns: %{current_user: current_user}} = socket) do
    friends =
      Account.list_friends(
        where: [
          either_user_is: current_user.id
        ],
        preload: [:user1, :user2]
      )
      |> Enum.map(fn friend ->
        other_user =
          if friend.user1_id == current_user.id do
            friend.user2
          else
            friend.user1
          end

        %{friend | other_user: other_user}
      end)
      |> Enum.sort_by(fn f -> String.downcase(f.other_user.name) end, &<=/2)

    incoming_friend_requests =
      Account.list_friend_requests(
        where: [
          to_user_id: current_user.id
        ],
        preload: [:from_user]
      )

    outgoing_friend_requests =
      Account.list_friend_requests(
        where: [
          from_user_id: current_user.id
        ],
        preload: [:to_user]
      )

    socket
    |> assign(:incoming_friend_requests, incoming_friend_requests)
    |> assign(:outgoing_friend_requests, outgoing_friend_requests)
    |> assign(:friends, friends)
    |> get_inactive_friend_count()
  end

  defp get_follows(%{assigns: %{current_user: current_user}} = socket) do
    follows =
      Account.list_relationships(
        where: [
          from_user_id: current_user.id,
          state: "follow"
        ],
        preload: [:to_user]
      )

    socket
    |> assign(:follows, follows)
  end

  defp get_avoids(%{assigns: %{current_user: current_user}} = socket) do
    relationships =
      Account.list_relationships(
        where: [
          from_user_id: current_user.id
        ],
        preload: [:to_user]
      )

    ignores =
      relationships
      |> Enum.filter(fn r ->
        r.ignore == true
      end)
      |> Enum.sort_by(fn r -> r.to_user.name end, &<=/2)

    avoids =
      relationships
      |> Enum.filter(fn r ->
        r.state == "avoid"
      end)
      |> Enum.sort_by(fn r -> r.to_user.name end, &<=/2)

    blocks =
      relationships
      |> Enum.filter(fn r ->
        r.state == "block"
      end)
      |> Enum.sort_by(fn r -> r.to_user.name end, &<=/2)

    socket
    |> assign(:avoids, avoids)
    |> assign(:ignores, ignores)
    |> assign(:blocks, blocks)
  end

  def get_purge_cutoff_options() do
    ["1 month", "3 months", "6 months", "1 year"]
  end

  def get_default_purge_cutoff_option() do
    "6 months"
  end

  @spec get_purge_days_cutoff(String.t()) :: float()
  def get_purge_days_cutoff(duration) do
    with [_, raw_number, type] <- Regex.run(~r/(\d)+ (month|year)/, duration),
         {number, ""} <- Integer.parse(raw_number) do
      cond do
        type == "year" ->
          number * 365

        type == "month" ->
          number * 365.0 / 12
      end
    else
      nil -> {:error, "invalid duration passed: #{duration}"}
      {_, _rest} -> {:error, "invalid number in duration #{duration}"}
    end
  end

  defp get_inactive_friend_count(socket) do
    friends = socket.assigns.friends
    purge_cutoff = socket.assigns.purge_cutoff

    socket =
      socket |> assign(:inactive_friend_count, get_inactive_friend_count(friends, purge_cutoff))

    socket
  end

  defp get_inactive_friend_count(friends, purge_cutoff_text) do
    days_cutoff = get_purge_days_cutoff(purge_cutoff_text)

    get_inactive_friends(friends, days_cutoff)
    |> length()
  end

  def get_inactive_friends(friends, days_cutoff) do
    Enum.filter(friends, fn friend ->
      last_login = friend.other_user.last_login
      days = get_days_diff(last_login, Timex.now())
      days > days_cutoff
    end)
  end

  def get_days_diff(datetime1, datetime2) do
    cond do
      datetime1 == nil -> 0
      datetime2 == nil -> 0
      true -> abs(DateTime.diff(datetime1, datetime2, :day))
    end
  end
end
