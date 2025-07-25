defmodule TeiserverWeb.Account.ProfileLive.Overview do
  @moduledoc false

  use TeiserverWeb, :live_view

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Lobby
  alias Teiserver.Account.AccoladeLib

  @impl true
  def mount(%{"userid" => userid_str}, _session, socket) do
    userid = String.to_integer(userid_str)
    user = Account.get_user_by_id(userid)

    socket =
      cond do
        user == nil ->
          socket
          |> put_flash(:info, "Unable to find that user")
          |> redirect(to: ~p"/")

        true ->
          :ok =
            PubSub.subscribe(
              Teiserver.PubSub,
              "teiserver_client_messages:#{userid}"
            )

          socket
          |> assign(:tab, nil)
          |> assign(:site_menu_active, "teiserver_account")
          |> assign(:view_colour, Teiserver.Account.UserLib.colours())
          |> assign(:user, user)
          |> assign(:role_data, Account.RoleLib.role_data())
          |> assign(:client, Account.get_client_by_id(userid))
          |> get_relationships_and_permissions
          |> assign_accolade_notification
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(%{assigns: %{user: user}} = socket, :overview, _params) do
    socket
    |> assign(:page_title, "#{user.name} - Overview")
  end

  defp apply_action(%{assigns: %{user: user}} = socket, :accolades, _params) do
    socket
    |> assign(:page_title, "#{user.name} - Accolades")
  end

  defp apply_action(%{assigns: %{user: user}} = socket, :achievements, _params) do
    socket
    |> assign(:page_title, "#{user.name} - Achievements")
  end

  @impl true
  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :connected}, socket) do
    user_id = socket.assigns.user.id

    socket = assign(socket, :client, Account.get_client_by_id(user_id))

    {:noreply, socket}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :disconnected}, socket) do
    {:noreply, assign(socket, :client, nil)}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _, event: :client_updated}, socket) do
    user_id = socket.assigns.user.id

    socket = assign(socket, :client, Account.get_client_by_id(user_id))

    {:noreply, socket}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join", _params, %{assigns: assigns} = socket) do
    current_user_id = assigns.current_user.id
    lobby_id = assigns.client.lobby_id

    with :ok <- client_connected(current_user_id),
         :ok <- server_allows_join(lobby_id, current_user_id),
         :ok <- join_lobby(lobby_id, current_user_id) do
      {:noreply, put_flash(socket, :success, "Lobby joined")}
    else
      {:error, reason} ->
        {:noreply, put_flash(socket, :warning, reason)}
    end
  end

  def handle_event(
        "follow-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.follow_user(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are now following #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "unfriend",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.delete_friend(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You have removed #{user.name} as a friend")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "reset-relationship-state",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.reset_relationship_state(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are now no longer following, avoiding or blocking #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "ignore-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.ignore_user(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are now ignoring #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "unignore-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.unignore_user(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are no longer ignoring #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "avoid-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.avoid_user(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are now avoiding #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "block-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.block_user(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "You are now blocking #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "unfriend-user",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.decline_friend_request(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "Request from #{user.name} declined")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "accept-friend-request",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.accept_friend_request(user.id, current_user.id)

    socket =
      socket
      |> put_flash(:success, "Request accepted, you are now friends with #{user.name}")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "decline-friend-request",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.decline_friend_request(user.id, current_user.id)

    socket =
      socket
      |> put_flash(:success, "Friend request declined")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "rescind-friend-request",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    Account.rescind_friend_request(current_user.id, user.id)

    socket =
      socket
      |> put_flash(:success, "Friend request rescinded")
      |> get_relationships_and_permissions()

    {:noreply, socket}
  end

  def handle_event(
        "create-friend-request",
        _event,
        %{assigns: %{current_user: current_user, user: user}} = socket
      ) do
    case Account.create_friend_request(current_user.id, user.id) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:success, "Friend request sent")
          |> get_relationships_and_permissions()

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:warning, "Unable to create friend request: #{reason}")

        {:noreply, socket}
    end
  end

  defp client_connected(user_id) do
    client = Account.get_client_by_id(user_id)

    if not is_nil(client) do
      :ok
    else
      {:error, "Client is not connected"}
    end
  end

  defp server_allows_join(lobby_id, user_id) do
    case Lobby.server_allows_join?(user_id, lobby_id) do
      true -> :ok
      {:failure, reason} -> {:error, reason}
    end
  end

  defp join_lobby(lobby_id, user_id) do
    if :ok == Lobby.force_add_user_to_lobby(user_id, lobby_id) do
      :ok
    else
      {:error, "Failed to join lobby"}
    end
  end

  def get_relationships_and_permissions(%{assigns: %{current_user: nil}} = socket) do
    socket
    |> assign(:relationship, [])
    |> assign(:friendship, [])
    |> assign(:friendship_request, [])
    |> assign(:profile_permissions, [])
  end

  def get_relationships_and_permissions(%{assigns: %{user: nil}} = socket) do
    socket
    |> assign(:relationship, [])
    |> assign(:friendship, [])
    |> assign(:friendship_request, [])
    |> assign(:profile_permissions, [])
  end

  def get_relationships_and_permissions(
        %{assigns: %{current_user: current_user, user: user}} = socket
      )
      when is_connected?(socket) do
    relationship = Account.get_relationship(current_user.id, user.id)
    friendship = Account.get_friend(current_user.id, user.id)

    friendship_request =
      Account.get_friend_request(nil, nil, where: [either_user_is: {current_user.id, user.id}])

    profile_permissions =
      Account.profile_view_permissions(
        current_user,
        user,
        relationship,
        friendship,
        friendship_request
      )

    socket
    |> assign(:relationship, relationship)
    |> assign(:friendship, friendship)
    |> assign(:friendship_request, friendship_request)
    |> assign(:profile_permissions, profile_permissions)
  end

  def get_relationships_and_permissions(socket) do
    socket
    |> assign(:relationship, nil)
    |> assign(:friendship, nil)
    |> assign(:friendship_request, nil)
    |> assign(:profile_permissions, [])
  end

  def assign_accolade_notification(socket) do
    message = get_accolade_notification_message(socket.assigns.user, socket.assigns.current_user)

    socket |> assign(:accolade_notification, message)
  end

  def get_accolade_notification_message(viewed_user, current_user) do
    days = 1

    with %{id: viewed_user_id} <- viewed_user,
         %{id: current_user_id} <- current_user,
         true <- viewed_user_id == current_user_id,
         %{map: map, giver_name: giver_name} <-
           AccoladeLib.recent_accolade(current_user_id, days) do
      "You have recently received an accolade from #{giver_name} for your match in #{map}!"
    else
      # Goes here if the viewed user is not the same as the logged in user
      # Or if there are no recent accolades
      _ -> nil
    end
  end
end
