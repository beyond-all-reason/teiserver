defmodule TeiserverWeb.Account.RelationshipLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account}

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:tab, nil)
      |> assign(:site_menu_active, "account")
      |> assign(:view_colour, Teiserver.Account.RelationshipLib.colours())
      |> put_empty_relationships

    {:ok, socket}
  end

  # @impl true
  # def handle_event(_cmd, _event, %{assigns: _assigns} = socket) do
  #   {:noreply, socket}
  # end


  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :friend, _params) do
    socket
      |> assign(:page_title, "Relationships - Friends")
      |> assign(:tab, :friend)
      |> get_friends()
  end

  defp apply_action(socket, :follow, _params) do
    socket
      |> assign(:page_title, "Relationships - Following")
      |> assign(:tab, :follow)
      |> get_follows()
  end

  defp apply_action(socket, :avoid, _params) do
    socket
      |> assign(:page_title, "Relationships - Avoids")
      |> assign(:tab, :avoid)
      |> get_avoids()
  end

  defp apply_action(socket, :search, _params) do
    socket
      |> assign(:page_title, "Relationships - Player search")
      |> assign(:tab, :search)
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
  end

  defp get_friends(%{assigns: %{current_user: current_user}} = socket) do
    friends = Account.list_friends(
      where: [
        either_user_is: current_user.id
      ],
      preload: [:user1, :user2]
    )
    |> Enum.map(fn friend ->
      other_user = if friend.user1_id == current_user.id do
        friend.user2
      else
        friend.user1
      end

      %{friend | other_user: other_user}
    end)
    |> Enum.sort_by(fn f -> String.downcase(f.other_user.name) end, &<=/2)

    incoming_friend_requests = Account.list_friend_requests(
      where: [
        to_user_id: current_user.id
      ],
      preload: [:from_user]
    )

    outgoing_friend_requests = Account.list_friend_requests(
      where: [
        from_user_id: current_user.id
      ],
      preload: [:to_user]
    )

    socket
      |> assign(:incoming_friend_requests, incoming_friend_requests)
      |> assign(:outgoing_friend_requests, outgoing_friend_requests)
      |> assign(:friends, friends)
  end

  defp get_follows(%{assigns: %{current_user: current_user}} = socket) do
    follows = Account.list_relationships(
      where: [
        from_user_id: current_user.id,
        state: "follow",
      ],
      preload: [:to_user]
    )

    socket
      |> assign(:follows, follows)
  end

  defp get_avoids(%{assigns: %{current_user: current_user}} = socket) do
    relationships = Account.list_relationships(
      where: [
        from_user_id: current_user.id,
        state_in: ~w(ignore avoid block),
      ],
      preload: [:to_user]
    )

    ignores = relationships
      |> Enum.filter(fn r ->
        r.state == "ignore"
      end)

    avoids = relationships
      |> Enum.filter(fn r ->
        r.state == "avoid"
      end)

    blocks = relationships
      |> Enum.filter(fn r ->
        r.state == "block"
      end)

    socket
      |> assign(:avoids, avoids)
      |> assign(:ignores, ignores)
      |> assign(:blocks, blocks)
  end
end
